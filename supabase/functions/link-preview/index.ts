// supabase/functions/link-preview/index.ts
//
// Reads the Open Graph tags of a page and caches them in public.link_previews.
// Deploy with JWT verification left ON (the default), so only signed-in users
// can call it:
//   supabase functions deploy link-preview
//
// The app never fetches the linked page itself: the server does it once for
// everyone, which keeps each user's address away from the sites they link to,
// and gives one place to enforce the safety checks below.
import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_BYTES = 100 * 1024; // read only the first 100 KB of the page
const MAX_REDIRECTS = 3;
const MAX_TEXT = 300;
const TIMEOUT_MS = 8000;
const CACHE_DAYS = 7;

/// True for every address the server must never fetch: loopback, private,
/// link-local, carrier-grade NAT and reserved space.
function isPrivateAddress(address: string): boolean {
  const value = address.trim().toLowerCase();
  if (value === "") return true;
  if (value === "::1" || value === "::") return true;
  // IPv6 unique-local (fc00::/7) and link-local (fe80::/10).
  if (/^f[cd][0-9a-f]{2}:/.test(value)) return true;
  if (/^fe[89ab][0-9a-f]:/.test(value)) return true;
  // IPv4, including the IPv4-mapped IPv6 form ::ffff:127.0.0.1.
  const mapped = value.match(/^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/);
  const ipv4 = mapped ? mapped[1] : value;
  const parts = ipv4.split(".");
  if (parts.length !== 4) return false; // a plain IPv6 address we already checked
  const [a, b] = parts.map((part) => Number(part));
  if ([a, b].some((n) => Number.isNaN(n) || n < 0 || n > 255)) return true;
  if (a === 0 || a === 10 || a === 127) return true;
  if (a === 169 && b === 254) return true; // link-local
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  if (a === 100 && b >= 64 && b <= 127) return true; // carrier-grade NAT
  if (a === 192 && b === 0) return true; // 192.0.0.0/24 and 192.0.2.0/24
  if (a === 198 && (b === 18 || b === 19)) return true; // benchmarking
  if (a >= 224) return true; // multicast and reserved
  return false;
}

/// Resolves a hostname and refuses it if any address is private. Checking the
/// text of the URL is not enough, because a public name can point at a private
/// address.
async function assertPublicHost(hostname: string): Promise<void> {
  const addresses: string[] = [];
  for (const type of ["A", "AAAA"] as const) {
    try {
      addresses.push(...(await Deno.resolveDns(hostname, type)));
    } catch {
      // No records of that type; the other type may still have some.
    }
  }
  if (addresses.length === 0) {
    throw new Error("That address could not be resolved.");
  }
  if (addresses.some(isPrivateAddress)) {
    throw new Error("That address points to a private network, so it is not allowed.");
  }
}

/// Follows redirects by hand, so every hop is checked. fetch() with
/// redirect: "follow" would skip the check on the hops it follows itself.
async function fetchPage(start: URL): Promise<Response> {
  let url = start;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    if (url.protocol !== "https:") {
      throw new Error("Only https links can be previewed.");
    }
    await assertPublicHost(url.hostname);
    const response = await fetch(url, {
      redirect: "manual",
      headers: { "user-agent": "ThreadsLinkPreview/1.0" },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (response.status >= 300 && response.status < 400) {
      await response.body?.cancel();
      const location = response.headers.get("location");
      if (!location) return response;
      url = new URL(location, url);
      continue;
    }
    return response;
  }
  throw new Error("That link redirected too many times.");
}

/// Reads at most MAX_BYTES of the body, so a huge or endless page cannot fill
/// the function's memory.
async function readHead(response: Response): Promise<string> {
  const reader = response.body?.getReader();
  if (!reader) return "";
  const decoder = new TextDecoder("utf-8");
  let text = "";
  let read = 0;
  while (read < MAX_BYTES) {
    const chunk = await reader.read();
    if (chunk.done) break;
    read += chunk.value.byteLength;
    text += decoder.decode(chunk.value, { stream: true });
    if (/<\/head>/i.test(text)) break;
  }
  reader.cancel().catch(() => {});
  return text;
}

function decodeEntities(value: string): string {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(Number(dec)))
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&");
}

/// Reads a <meta> value by property or name, e.g. "og:title".
function metaContent(html: string, key: string): string | null {
  const tag = html.match(
    new RegExp(`<meta[^>]+(?:property|name)=["']${key}["'][^>]*>`, "i"),
  )?.[0];
  if (!tag) return null;
  const content = tag.match(/content=["']([^"']*)["']/i)?.[1];
  const clean = content ? decodeEntities(content).trim().slice(0, MAX_TEXT) : "";
  return clean.length > 0 ? clean : null;
}

Deno.serve(async (req) => {
  const json = (body: unknown, status = 200) => Response.json(body, { status });

  let url: URL;
  try {
    const body = await req.json();
    url = new URL(String(body?.url ?? ""));
  } catch {
    return json({ error: "Send a JSON body with a url field." }, 400);
  }
  if (url.protocol !== "https:") {
    return json({ error: "Only https links can be previewed." }, 400);
  }

  // The service role key lives only in this function's environment, never in
  // the app.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const key = url.toString();
  const fresh = new Date(Date.now() - CACHE_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { data: cached } = await admin
    .from("link_previews")
    .select("url, title, description, image_url")
    .eq("url", key)
    .gt("fetched_at", fresh)
    .maybeSingle();
  if (cached) return json(cached);

  let preview: {
    url: string;
    title: string | null;
    description: string | null;
    image_url: string | null;
  };
  try {
    const response = await fetchPage(url);
    if (!response.ok) {
      return json({ error: `That page returned ${response.status}.` }, 502);
    }
    const contentType = response.headers.get("content-type") ?? "";
    if (!contentType.includes("html")) {
      return json({ error: "That link is not an HTML page." }, 415);
    }
    const html = await readHead(response);

    let imageUrl = metaContent(html, "og:image") ?? metaContent(html, "twitter:image");
    if (imageUrl !== null) {
      try {
        const image = new URL(imageUrl, url);
        if (image.protocol !== "https:") {
          imageUrl = null;
        } else {
          await assertPublicHost(image.hostname);
          imageUrl = image.toString();
        }
      } catch {
        imageUrl = null;
      }
    }

    const rawTitle = html.match(/<title[^>]*>([^<]*)<\/title>/i)?.[1]?.trim() ?? "";
    preview = {
      url: key,
      title: metaContent(html, "og:title")
        ?? metaContent(html, "twitter:title")
        ?? (rawTitle.length > 0 ? decodeEntities(rawTitle).slice(0, MAX_TEXT) : null),
      description: metaContent(html, "og:description")
        ?? metaContent(html, "twitter:description")
        ?? metaContent(html, "description"),
      image_url: imageUrl,
    };
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "That link could not be loaded.";
    return json({ error: message }, 400);
  }

  await admin.from("link_previews").upsert({
    ...preview,
    fetched_at: new Date().toISOString(),
  });

  return json(preview);
});
