// supabase/functions/instagram-publish/index.ts
//
// Step 21.6 — shares one thread to Instagram, and (best effort) removes the
// copy when the thread is deleted.
//
// It reads the connected account's token from Supabase Vault through the
// get_instagram_token helper, so the token never leaves the server. Deploy with
// JWT verification ON (the default): only signed-in users call it, and it
// checks that the thread belongs to the caller.
//
//   supabase functions deploy instagram-publish
//
// A failed publish never changes the thread: the outcome is recorded in
// instagram_posts (status/error) and returned to the app, which shows which
// copy failed.

import { createClient } from "npm:@supabase/supabase-js@2";

const GRAPH = "https://graph.facebook.com/v21.0";

// Instagram captions are longer than a thread, so a thread always fits; the
// limit is here for clarity.
const CAPTION_MAX = 2200;
const VIDEO_WAIT_MS = 60000;
const VIDEO_POLL_MS = 4000;

type Thread = {
  content: string | null;
  media_urls: string[] | null;
  media_kinds: string[] | null;
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

function kindAt(thread: Thread, index: number): string {
  const kinds = thread.media_kinds ?? [];
  if (index < kinds.length && kinds[index]) return kinds[index];
  const path = (thread.media_urls?.[index] ?? "").toLowerCase().split("?")[0];
  if (path.endsWith(".mp4") || path.endsWith(".mov")) return "video";
  return "image";
}

/// Instagram's publishing API only accepts JPEG stills.
function isJpeg(url: string): boolean {
  const path = url.toLowerCase().split("?")[0];
  return path.endsWith(".jpg") || path.endsWith(".jpeg");
}

async function graphPost(
  path: string,
  params: Record<string, string>,
): Promise<any> {
  const response = await fetch(`${GRAPH}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(params),
    signal: AbortSignal.timeout(20000),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body?.error) {
    throw new Error(
      body?.error?.message ?? `Instagram refused the request (${response.status}).`,
    );
  }
  return body;
}

async function graphGet(
  path: string,
  params: Record<string, string>,
): Promise<any> {
  const target = new URL(`${GRAPH}${path}`);
  for (const [key, value] of Object.entries(params)) {
    target.searchParams.set(key, value);
  }
  const response = await fetch(target, { signal: AbortSignal.timeout(15000) });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body?.error) {
    throw new Error(
      body?.error?.message ?? `Instagram refused the request (${response.status}).`,
    );
  }
  return body;
}

/// Meta processes video containers asynchronously; wait until the container is
/// ready before it is published.
async function waitForContainer(
  containerId: string,
  token: string,
): Promise<void> {
  const deadline = Date.now() + VIDEO_WAIT_MS;
  while (Date.now() < deadline) {
    const status = await graphGet(`/${containerId}`, {
      fields: "status_code",
      access_token: token,
    });
    const code = String(status?.status_code ?? "");
    if (code === "FINISHED") return;
    if (code === "ERROR" || code === "EXPIRED") {
      throw new Error(
        `Instagram could not process the media (${code.toLowerCase()}).`,
      );
    }
    await new Promise((resolve) => setTimeout(resolve, VIDEO_POLL_MS));
  }
  throw new Error("Instagram took too long to process the media.");
}

/// One photo or one video.
async function publishOne(
  igUserId: string,
  token: string,
  url: string,
  kind: string,
  caption: string,
): Promise<string> {
  const params: Record<string, string> = { access_token: token, caption };
  if (kind === "video") {
    params.media_type = "REELS";
    params.video_url = url;
  } else {
    params.image_url = url;
  }
  const container = await graphPost(`/${igUserId}/media`, params);
  if (kind === "video") await waitForContainer(String(container.id), token);
  const published = await graphPost(`/${igUserId}/media_publish`, {
    access_token: token,
    creation_id: String(container.id),
  });
  return String(published.id);
}

/// Two to ten items in one post.
async function publishCarousel(
  igUserId: string,
  token: string,
  urls: string[],
  kinds: string[],
  caption: string,
): Promise<string> {
  const children: string[] = [];
  for (let i = 0; i < urls.length; i++) {
    const isVideo = kinds[i] === "video";
    const params: Record<string, string> = {
      access_token: token,
      is_carousel_item: "true",
      media_type: isVideo ? "VIDEO" : "IMAGE",
    };
    if (isVideo) params.video_url = urls[i];
    else params.image_url = urls[i];
    const child = await graphPost(`/${igUserId}/media`, params);
    if (isVideo) await waitForContainer(String(child.id), token);
    children.push(String(child.id));
  }
  const container = await graphPost(`/${igUserId}/media`, {
    access_token: token,
    media_type: "CAROUSEL",
    children: children.join(","),
    caption,
  });
  const published = await graphPost(`/${igUserId}/media_publish`, {
    access_token: token,
    creation_id: String(container.id),
  });
  return String(published.id);
}

async function publish(
  admin: ReturnType<typeof createClient>,
  userId: string,
  threadId: string,
  thread: Thread,
  igUserId: string,
  token: string,
): Promise<Response> {
  const urls = (thread.media_urls ?? [])
    .filter((url) => typeof url === "string" && url.startsWith("http"))
    .slice(0, 10);

  if (urls.length === 0) {
    return json(
      { error: "Instagram needs a photo or a video. Add one, then post again." },
      400,
    );
  }

  const kinds = urls.map((_, index) => kindAt(thread, index));
  if (urls.some((url, index) => kinds[index] !== "video" && !isJpeg(url))) {
    return json(
      { error: "Instagram only accepts JPEG photos and MP4 or MOV videos." },
      400,
    );
  }

  const caption = (thread.content ?? "").slice(0, CAPTION_MAX);

  await admin.from("instagram_posts").upsert({
    thread_id: threadId,
    user_id: userId,
    status: "pending",
    error: null,
  });

  try {
    const mediaId = urls.length === 1
      ? await publishOne(igUserId, token, urls[0], kinds[0], caption)
      : await publishCarousel(igUserId, token, urls, kinds, caption);
    await admin
      .from("instagram_posts")
      .update({ status: "published", ig_media_id: mediaId, error: null })
      .eq("thread_id", threadId);
    return json({ ok: true, ig_media_id: mediaId });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "The Instagram copy failed.";
    await admin
      .from("instagram_posts")
      .update({ status: "failed", error: message })
      .eq("thread_id", threadId);
    return json({ error: message }, 502);
  }
}

/// Removes the Instagram copy of one thread, if there is one.
async function removeCopy(
  admin: ReturnType<typeof createClient>,
  threadId: string,
  token: string,
): Promise<Response> {
  const { data } = await admin
    .from("instagram_posts")
    .select("ig_media_id")
    .eq("thread_id", threadId)
    .maybeSingle();

  const mediaId = data?.ig_media_id;
  if (!mediaId) return json({ ok: true, note: "There was no Instagram copy." });

  // Instagram's Content Publishing API has no endpoint for deleting published
  // media. Try anyway (it may exist for some account types), and otherwise tell
  // the caller it has to be removed in the Instagram app.
  try {
    const response = await fetch(
      `${GRAPH}/${mediaId}?access_token=${encodeURIComponent(token)}`,
      { method: "DELETE", signal: AbortSignal.timeout(15000) },
    );
    const body = await response.json().catch(() => ({}));
    if (response.ok && !body?.error) {
      return json({ ok: true, note: "The Instagram copy was removed." });
    }
  } catch {
    // Fall through to the note below.
  }
  return json({
    ok: false,
    note: "Instagram does not let an app delete a published post. Remove it in the Instagram app.",
  });
}

Deno.serve(async (req) => {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const token = (req.headers.get("authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const userId = userData?.user?.id;
  if (userError || !userId) return json({ error: "Sign in again." }, 401);

  let body: Record<string, any> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const threadId = String(body?.thread_id ?? "");
  if (threadId === "") return json({ error: "Missing thread." }, 400);

  const { data: thread } = await admin
    .from("threads")
    .select("id, author_id, content, media_urls, media_kinds")
    .eq("id", threadId)
    .maybeSingle();
  if (!thread || thread.author_id !== userId) {
    return json({ error: "That is not your thread." }, 403);
  }

  const { data: account } = await admin
    .from("instagram_accounts")
    .select("ig_user_id")
    .eq("user_id", userId)
    .maybeSingle();
  if (!account?.ig_user_id) {
    return json({ error: "Connect an Instagram account first." }, 400);
  }

  const { data: storedToken, error: tokenError } = await admin.rpc(
    "get_instagram_token",
    { p_user_id: userId },
  );
  if (tokenError) return json({ error: tokenError.message }, 500);
  const accessToken = typeof storedToken === "string" ? storedToken : "";
  if (accessToken === "") {
    return json({ error: "Reconnect your Instagram account." }, 400);
  }

  if (String(body?.action) === "delete") {
    return await removeCopy(admin, threadId, accessToken);
  }
  return await publish(
    admin,
    userId,
    threadId,
    thread as Thread,
    String(account.ig_user_id),
    accessToken,
  );
});
