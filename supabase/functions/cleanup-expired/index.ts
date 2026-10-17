// supabase/functions/cleanup-expired/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

const BATCH = 200;

// Media URLs look like .../storage/v1/object/public/thread-media/<user>/<file>.
// This returns the part after the bucket name, which is the path inside the bucket.
function storagePath(url: string): string | null {
  const marker = "/thread-media/";
  const at = url.indexOf(marker);
  if (at === -1) return null;
  return url.slice(at + marker.length).split("?")[0];
}

Deno.serve(async (req) => {
  // Only the scheduler knows this secret, so the function cannot be run by strangers.
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("Forbidden", { status: 403 });
  }

  // The service role key lives only in this function's environment, never in the app.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: expired, error } = await admin
    .from("threads")
    .select("id, media_urls")
    .lt("expires_at", new Date().toISOString())
    .limit(BATCH);
  if (error) return new Response(error.message, { status: 500 });

  const rows = expired ?? [];
  const files = rows
    .flatMap((row) => row.media_urls as string[])
    .map(storagePath)
    .filter((path): path is string => path !== null);

  // Files first. If this fails, the rows stay, and the next run tries again.
  if (files.length > 0) {
    const { error: removeError } = await admin.storage
      .from("thread-media")
      .remove(files);
    if (removeError) return new Response(removeError.message, { status: 500 });
  }

  const ids = rows.map((row) => row.id);
  if (ids.length > 0) {
    const { error: deleteError } = await admin
      .from("threads")
      .delete()
      .in("id", ids);
    if (deleteError) return new Response(deleteError.message, { status: 500 });
  }

  // Replies to a deleted post are removed by the parent_id cascade from Step 2.
  return Response.json({ threads: ids.length, files: files.length });
});
