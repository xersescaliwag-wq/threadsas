// supabase/functions/gif-search/index.ts
//
// Searches GIPHY or Tenor for GIFs. The provider key is a secret, so it stays
// in this function and never ships in the app, where anyone could read it out
// (Step 21.3).
//
// Deploy with JWT verification left ON (the default) and set one provider key:
//   supabase secrets set GIPHY_API_KEY=...      (from developers.giphy.com)
//   supabase secrets set TENOR_API_KEY=...      (from console.cloud.google.com)
//   supabase functions deploy gif-search
//
// The function also checks the caller's token itself, so only signed-in users
// can search even if the platform gate is ever loosened.
import { createClient } from "npm:@supabase/supabase-js@2";

const LIMIT = 24;
const MAX_QUERY = 60;
const TIMEOUT_MS = 8000;

/// One normalized result: a small preview for the picker and the full GIF that
/// gets stored in media_urls.
type Gif = {
  id: string;
  preview_url: string;
  full_url: string;
  width: number;
  height: number;
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

async function searchGiphy(key: string, query: string): Promise<Gif[]> {
  const url = new URL(
    query === ""
      ? "https://api.giphy.com/v1/gifs/trending"
      : "https://api.giphy.com/v1/gifs/search",
  );
  url.searchParams.set("api_key", key);
  if (query !== "") url.searchParams.set("q", query);
  url.searchParams.set("limit", String(LIMIT));
  url.searchParams.set("rating", "pg-13");
  const response = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!response.ok) throw new Error("The GIF provider refused the search.");
  const body = await response.json();
  const data = Array.isArray(body?.data) ? body.data : [];
  return data
    .map((item: Record<string, any>) => {
      const images = item?.images ?? {};
      const preview = images.fixed_width ?? images.downsized_small ??
        images.fixed_width_small ?? {};
      const full = images.downsized ?? images.original ?? images.fixed_height ?? {};
      return {
        id: String(item?.id ?? ""),
        preview_url: String(preview.url ?? ""),
        full_url: String(full.url ?? preview.url ?? ""),
        width: Number(full.width ?? preview.width ?? 0) || 0,
        height: Number(full.height ?? preview.height ?? 0) || 0,
      };
    })
    .filter((gif: Gif) => gif.preview_url !== "" && gif.full_url !== "");
}

async function searchTenor(key: string, query: string): Promise<Gif[]> {
  const url = new URL(
    query === ""
      ? "https://tenor.googleapis.com/v2/featured"
      : "https://tenor.googleapis.com/v2/search",
  );
  url.searchParams.set("key", key);
  if (query !== "") url.searchParams.set("q", query);
  url.searchParams.set("limit", String(LIMIT));
  url.searchParams.set("media_filter", "gif,tinygif");
  url.searchParams.set("contentfilter", "medium");
  const response = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!response.ok) throw new Error("The GIF provider refused the search.");
  const body = await response.json();
  const data = Array.isArray(body?.results) ? body.results : [];
  return data
    .map((item: Record<string, any>) => {
      const formats = item?.media_formats ?? {};
      const preview = formats.tinygif ?? formats.tinygif_transparent ?? formats.gif ?? {};
      const full = formats.gif ?? formats.mediumgif ?? formats.tinygif ?? {};
      const dims = Array.isArray(full.dims) ? full.dims : [];
      return {
        id: String(item?.id ?? ""),
        preview_url: String(preview.url ?? ""),
        full_url: String(full.url ?? preview.url ?? ""),
        width: Number(dims[0] ?? 0) || 0,
        height: Number(dims[1] ?? 0) || 0,
      };
    })
    .filter((gif: Gif) => gif.preview_url !== "" && gif.full_url !== "");
}

Deno.serve(async (req) => {
  // Only signed-in users may search, so the provider key is never spent on
  // anonymous traffic.
  const token = (req.headers.get("authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  if (token === "") {
    return json({ error: "Sign in to search for GIFs." }, 401);
  }
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    return json({ error: "Your session has expired. Sign in again." }, 401);
  }

  let query = "";
  try {
    const body = await req.json();
    query = String(body?.query ?? "").trim().slice(0, MAX_QUERY);
  } catch {
    query = "";
  }

  const giphyKey = Deno.env.get("GIPHY_API_KEY");
  const tenorKey = Deno.env.get("TENOR_API_KEY");
  if (!giphyKey && !tenorKey) {
    return json(
      { error: "GIF search is not set up. Add a provider key secret." },
      500,
    );
  }

  try {
    const results = giphyKey
      ? await searchGiphy(giphyKey, query)
      : await searchTenor(tenorKey!, query);
    return json({ results });
  } catch (error) {
    const message = error instanceof Error ? error.message : "The search failed.";
    return json({ error: message }, 502);
  }
});
