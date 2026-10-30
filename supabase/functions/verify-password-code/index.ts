import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => Response.json(body, { status, headers: { "Access-Control-Allow-Origin": "*" } });
const hash = async (value: string) => {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
};
const token = () => {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  try {
    const body = await req.json();
    const email = String(body?.email ?? "").trim().toLowerCase();
    const value = String(body?.code ?? "").trim();
    if (!/^\d{8}$/.test(value)) return json({ error: "Enter the 8-digit code." }, 400);
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const result = await admin.from("password_reset_codes").select("*").eq("email", email).is("used_at", null).order("created_at", { ascending: false }).limit(1).maybeSingle();
    const record = result.data;
    if (result.error || !record || new Date(record.expires_at).getTime() < Date.now()) return json({ error: "The code is invalid or expired." }, 400);
    if (record.attempts >= record.max_attempts) return json({ error: "Too many attempts. Request a new code." }, 429);
    if (await hash(value) !== record.code_hash) {
      await admin.from("password_reset_codes").update({ attempts: record.attempts + 1 }).eq("id", record.id);
      return json({ error: "The code is incorrect." }, 400);
    }
    const verificationToken = token();
    await admin.from("password_reset_codes").update({ verified_at: new Date().toISOString(), verification_token_hash: await hash(verificationToken), verification_token_expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString() }).eq("id", record.id);
    return json({ verification_token: verificationToken });
  } catch (_) {
    return json({ error: "Unable to verify the code." }, 500);
  }
});
