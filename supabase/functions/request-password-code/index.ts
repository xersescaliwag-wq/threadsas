import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "Access-Control-Allow-Origin": "*" } });

const hash = async (value: string) => {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
};

const code = () => {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return String(10000000 + (bytes[0] % 90000000));
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  try {
    const body = await req.json();
    const email = String(body?.email ?? "").trim().toLowerCase();
    if (!email || !email.includes("@")) return json({ error: "Enter a valid email address." }, 400);

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    const user = users.data.users.find((item) => item.email?.toLowerCase() === email);
    // Do not reveal whether an email belongs to an account.
    if (!user) return json({ ok: true });

    const value = code();
    const codeHash = await hash(value);
    await admin.from("password_reset_codes").insert({ email, code_hash: codeHash, expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString() });

    const resend = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("MAIL_FROM");
    if (!resend || !from) return json({ error: "Password reset email is not configured." }, 500);
    const mail = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resend}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to: [email], subject: "Your Threads password reset code", text: `Your 8-digit password reset code is ${value}. It expires in 10 minutes.` }),
    });
    if (!mail.ok) return json({ error: "Unable to send the reset email." }, 502);
    return json({ ok: true });
  } catch (_) {
    return json({ error: "Unable to request a password reset code." }, 500);
  }
});
