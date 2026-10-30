// Publishes due rows from scheduled_posts. Invoke from pg_cron or an external
// scheduler with the service role; the service key never reaches the client.
import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cronSecret = Deno.env.get("CRON_SECRET");
const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

Deno.serve(async (request) => {
  if (cronSecret && request.headers.get("x-cron-secret") !== cronSecret) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { data: jobs, error } = await admin
    .from("scheduled_posts")
    .select("id, owner_id, content, media_urls, media_kinds, metadata")
    .eq("status", "scheduled")
    .lte("scheduled_for", new Date().toISOString())
    .order("scheduled_for", { ascending: true })
    .limit(50);
  if (error) return Response.json({ error: error.message }, { status: 500 });

  const published: string[] = [];
  for (const job of jobs ?? []) {
    const claimed = await admin
      .from("scheduled_posts")
      .update({ status: "publishing", updated_at: new Date().toISOString() })
      .eq("id", job.id)
      .eq("status", "scheduled")
      .select("id")
      .maybeSingle();
    if (claimed.error || !claimed.data) continue;

    const { data: thread, error: publishError } = await admin
      .from("threads")
      .insert({
        ...(job.metadata ?? {}),
        author_id: job.owner_id,
        content: job.content,
        media_urls: job.media_urls ?? [],
        media_kinds: job.media_kinds ?? [],
      })
      .select("id")
      .single();

    if (publishError) {
      await admin.from("scheduled_posts").update({
        status: "failed",
        error_message: publishError.message,
        updated_at: new Date().toISOString(),
      }).eq("id", job.id);
      continue;
    }
    await admin.from("scheduled_posts").update({
      status: "published",
      published_thread_id: thread.id,
      updated_at: new Date().toISOString(),
    }).eq("id", job.id);
    published.push(job.id);
  }

  return Response.json({ processed: jobs?.length ?? 0, published });
});
