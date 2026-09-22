// Optional invite-email Edge Function (Phase 2, "backend email send").
//
// The app's primary invite channels are QR + share sheet (WhatsApp/SMS —
// how Zimbabwean families actually share). This function adds email on top;
// it is OPTIONAL and nothing in the app depends on it.
//
// Deploy:
//   supabase functions deploy invite-email
//   supabase secrets set RESEND_API_KEY=re_xxx  (or any provider you wire)
//
// Call (e.g. from a DB webhook on family_invite insert, or from your own
// tooling):
//   curl -X POST https://<project>.functions.supabase.co/invite-email \
//     -H "Authorization: Bearer <service_role>" \
//     -d '{"email":"tino@example.com","code":"MHRI-AB12CD","role":"teen",
//          "family":"The Moyo Family"}'
//
// Anti-enumeration note: the email never states whether the code is valid —
// it only restates what the sender already knows.

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('POST only', { status: 405 });
  }
  const key = Deno.env.get('RESEND_API_KEY');
  if (!key) {
    return new Response('RESEND_API_KEY not configured', { status: 500 });
  }
  const { email, code, role, family } = await req.json();
  if (!email || !code) {
    return new Response('email and code required', { status: 400 });
  }

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: Deno.env.get('INVITE_FROM') ?? 'Mhuri Hub <invites@mhuri.app>',
      to: [email],
      subject: `You're invited to ${family ?? 'our family'} on Mhuri Hub`,
      html: `
        <p>You have been invited as <b>${role ?? 'member'}</b> of
           <b>${family ?? 'a family'}</b> on Mhuri Hub.</p>
        <p>Open the app, choose <b>Join a family</b> and enter:</p>
        <p style="font-size:22px;letter-spacing:3px"><b>${code}</b></p>
        <p>Or scan the QR your family shows you. The invite expires in 7 days.</p>
      `,
    }),
  });

  if (!res.ok) {
    return new Response(await res.text(), { status: 502 });
  }
  return Response.json({ sent: true });
});
