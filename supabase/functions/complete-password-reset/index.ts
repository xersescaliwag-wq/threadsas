import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => Response.json(body, { status, headers: { "Access-Control-Allow-Origin": "*" } });
const hash = async (value: string) => {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  try {
    const body = await req.json();
    const email = String(body?.email ?? "").trim().toLowerCase();
    const verificationToken = String(body?.verification_token ?? "");
    const password = String(body?.password ?? "");
    if (password.length < 8) return json({ error: "Password must be at least 8 characters." }, 400);
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const result = await admin.from("password_reset_codes").select("*").eq("email", email).is("used_at", null).not("verified_at", "is", null).order("verified_at", { ascending: false }).limit(1).maybeSingle();
    const record = result.data;
    if (result.error || !record || new Date(record.verification_token_expires_at).getTime() < Date.now() || await hash(verificationToken) !== record.verification_token_hash) return json({ error: "The verification session is invalid or expired." }, 400);
    const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    const user = users.data.users.find((item) => item.email?.toLowerCase() === email);
    if (!user) return json({ error: "Unable to update this account." }, 400);
    const update = await admin.auth.admin.updateUserById(user.id, { password });
    if (update.error) return json({ error: "Unable to update the password." }, 500);
    await admin.from("password_reset_codes").update({ used_at: new Date().toISOString() }).eq("id", record.id);
    return json({ ok: true });
  } catch (_) {
    return json({ error: "Unable to complete the password reset." }, 500);
  }
});
