// supabase/functions/instagram-oauth/index.ts
//
// Step 21.6 — connects (and disconnects) an Instagram professional account.
//
// The whole OAuth flow runs inside this function, so Meta's app secret and the
// account's access token never reach the app. The token is handed to the
// set_instagram_credentials database helper, which stores it in Supabase Vault;
// only the service role (which the functions use) can read it back.
//
// Deploy it with JWT verification OFF, because Meta redirects the browser back
// to this function without a Supabase token:
//
//   supabase secrets set META_APP_ID=... META_APP_SECRET=...
//   supabase functions deploy instagram-oauth --no-verify-jwt
//
// The function still guards itself: "start" and "disconnect" require a real
// user token, and the callback is guarded by the signed "state" value.
//
// In the Meta app add this exact redirect URI (the project ref is in
// lib/core/config.dart):
//   https://<project-ref>.supabase.co/functions/v1/instagram-oauth

import { createClient } from "npm:@supabase/supabase-js@2";

const GRAPH = "https://graph.facebook.com/v21.0";

// What the app asks Meta for. instagram_content_publish is the one that needs
// Meta's review; the others are read permissions.
const SCOPES = [
  "instagram_basic",
  "instagram_content_publish",
  "pages_show_list",
  "pages_read_engagement",
  "business_management",
].join(",");

const encoder = new TextEncoder();

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

function html(message: string, status = 200): Response {
  return new Response(
    `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Instagram</title></head>
<body style="font-family:-apple-system,system-ui,sans-serif;text-align:center;padding:48px 24px;line-height:1.5">
${message}</body></html>`,
    { status, headers: { "content-type": "text/html; charset=utf-8" } },
  );
}

function config() {
  return {
    url: Deno.env.get("SUPABASE_URL")!,
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    appId: Deno.env.get("META_APP_ID"),
    appSecret: Deno.env.get("META_APP_SECRET"),
  };
}

/// The address Meta sends the browser back to, which is this same function.
function redirectUri(url: URL): string {
  return `${url.origin}${url.pathname}`;
}

/// HMAC key for the "state" value. It falls back to the service role key,
/// which is always present and secret, so no extra setup is required.
async function stateKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("INSTAGRAM_STATE_SECRET") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/// Signs "userId.random" so the callback can trust who started the flow
/// without a Supabase token.
async function signState(userId: string): Promise<string> {
  const payload = `${userId}.${crypto.randomUUID()}`;
  const signature = await crypto.subtle.sign(
    "HMAC",
    await stateKey(),
    encoder.encode(payload),
  );
  return `${payload}|${toBase64(new Uint8Array(signature))}`;
}

/// Returns the user id when the state is intact, or null when it is not.
async function readState(state: string): Promise<string | null> {
  const split = state.lastIndexOf("|");
  if (split < 0) return null;
  const payload = state.slice(0, split);
  const provided = state.slice(split + 1);
  const signature = await crypto.subtle.sign(
    "HMAC",
    await stateKey(),
    encoder.encode(payload),
  );
  if (provided !== toBase64(new Uint8Array(signature))) return null;
  return payload.split(".")[0] || null;
}

/// The user id behind a Supabase access token, or null.
async function userIdFromRequest(
  req: Request,
  admin: ReturnType<typeof createClient>,
): Promise<string | null> {
  const token = (req.headers.get("authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  if (token === "") return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user) return null;
  return data.user.id;
}

/// One Graph API call that returns JSON, and turns Meta's error shape into a
/// readable message.
async function graph(
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

async function handleStart(
  req: Request,
  url: URL,
  admin: ReturnType<typeof createClient>,
): Promise<Response> {
  const userId = await userIdFromRequest(req, admin);
  if (userId === null) return json({ error: "Sign in again." }, 401);

  const { appId, appSecret } = config();
  if (!appId || !appSecret) {
    return json(
      { error: "Instagram is not set up. Add META_APP_ID and META_APP_SECRET." },
      500,
    );
  }

  const authorize = new URL("https://www.facebook.com/v21.0/dialog/oauth");
  authorize.searchParams.set("client_id", appId);
  authorize.searchParams.set("redirect_uri", redirectUri(url));
  authorize.searchParams.set("state", await signState(userId));
  authorize.searchParams.set("scope", SCOPES);
  authorize.searchParams.set("response_type", "code");
  return json({ url: authorize.toString() });
}

async function handleCallback(
  url: URL,
  admin: ReturnType<typeof createClient>,
): Promise<Response> {
  const code = url.searchParams.get("code") ?? "";
  const userId = await readState(url.searchParams.get("state") ?? "");
  if (!userId) {
    return html(
      "<h2>This link is not valid</h2><p>Start again from the Threads app.</p>",
      400,
    );
  }

  const { appId, appSecret } = config();
  if (!appId || !appSecret) {
    return html(
      "<h2>Instagram is not set up</h2><p>Add the Meta app secrets, then try again.</p>",
      500,
    );
  }

  try {
    // 1. The one-time code becomes a short-lived user token.
    const short = await graph("/oauth/access_token", {
      client_id: appId,
      client_secret: appSecret,
      redirect_uri: redirectUri(url),
      code,
    });

    // 2. Exchange it for a long-lived user token (about 60 days).
    const long = await graph("/oauth/access_token", {
      grant_type: "fb_exchange_token",
      client_id: appId,
      client_secret: appSecret,
      fb_exchange_token: short.access_token,
    });

    // 3. Find the Facebook Page that has an Instagram professional account
    //    linked, and take that Page's token: it is the one the publishing API
    //    accepts.
    const pages = await graph("/me/accounts", {
      fields: "id,name,access_token,instagram_business_account{id,username}",
      access_token: long.access_token,
    });
    const page = (pages?.data ?? []).find(
      (item: Record<string, any>) => item?.instagram_business_account?.id,
    );
    if (!page) {
      return html(
        "<h2>No Instagram account found</h2><p>Link an Instagram professional account to a Facebook Page you manage, then try again.</p>",
        409,
      );
    }

    const expiresAt = long.expires_in
      ? new Date(Date.now() + Number(long.expires_in) * 1000).toISOString()
      : null;

    const { error } = await admin.rpc("set_instagram_credentials", {
      p_user_id: userId,
      p_ig_user_id: String(page.instagram_business_account.id),
      p_page_id: String(page.id),
      p_username: page.instagram_business_account.username ?? null,
      p_token: String(page.access_token ?? long.access_token),
      p_expires_at: expiresAt,
    });
    if (error) throw new Error(error.message);

    return html(
      "<h2>Instagram connected</h2><p>You can close this tab and return to the Threads app.</p>",
    );
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "The connection failed.";
    return html(`<h2>Could not connect</h2><p>${message}</p>`, 502);
  }
}

async function handleDisconnect(
  req: Request,
  admin: ReturnType<typeof createClient>,
): Promise<Response> {
  const userId = await userIdFromRequest(req, admin);
  if (userId === null) return json({ error: "Sign in again." }, 401);
  const { error } = await admin.rpc("disconnect_instagram", {
    p_user_id: userId,
  });
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const { url: supabaseUrl, serviceKey } = config();
  const admin = createClient(supabaseUrl, serviceKey);

  // Meta sends the browser back here with ?code and ?state.
  if (req.method === "GET" && url.searchParams.has("code")) {
    return await handleCallback(url, admin);
  }
  // ...or with ?error when the person tapped "Cancel".
  if (req.method === "GET" && url.searchParams.has("error")) {
    return html(
      "<h2>Instagram was not connected</h2><p>You can close this tab and try again from the app.</p>",
      400,
    );
  }

  let body: Record<string, any> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const action = String(body?.action ?? "");
  if (action === "start") return await handleStart(req, url, admin);
  if (action === "disconnect") return await handleDisconnect(req, admin);
  return json({ error: "Unknown action." }, 400);
});
