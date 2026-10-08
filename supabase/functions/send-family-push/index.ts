import { createClient } from 'npm:@supabase/supabase-js@2';
import { GoogleAuth } from 'npm:google-auth-library@9';

type Activity = {
  space_id: string;
  actor_id: string;
  action: string;
  detail?: Record<string, unknown>;
};

type ChatMessage = {
  id: string;
  space_id: string;
  sender_id: string;
  sender_name?: string;
  text?: string;
  media_url?: string;
  sticker?: string;
  deleted?: boolean;
};

const messages: Record<string, [string, string]> = {
  'tx.create': ['New family transaction', 'A transaction was added to your family ledger.'],
  'goal.contribute': ['Savings goal updated', 'A contribution was added to a family goal.'],
  'request.create': ['New family request', 'A family request is waiting for review.'],
  'request.approve': ['Request approved', 'A family request was approved.'],
  'request.decline': ['Request declined', 'A family request was declined.'],
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('POST only', { status: 405 });
  const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!webhookSecret || req.headers.get('x-webhook-secret') !== webhookSecret) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload = await req.json();
  const raw = payload.record ?? payload;
  const isChat = payload.table === 'family_chat_message';
  const chat = raw as ChatMessage;
  const record: Activity = isChat
    ? {
        space_id: chat.space_id,
        actor_id: chat.sender_id,
        action: 'chat.message',
      }
    : (raw as Activity);
  const copy: [string, string] | undefined = isChat && !chat.deleted
    ? [
        chat.sender_name?.trim() || 'New family message',
        chat.text?.trim() ||
          (chat.sticker ? `Sent a sticker ${chat.sticker}` : null) ||
          (chat.media_url ? 'Sent a photo.' : null) ||
          'A family member sent an update.',
      ]
    : messages[record.action];
  if (!copy || !record.space_id) return Response.json({ sent: 0, ignored: true });

  const url = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')!);
  const db = createClient(url, serviceKey);

  let memberQuery = db.from('membership').select('user_id').eq('space_id', record.space_id);
  if (record.action.startsWith('request.') && record.detail?.requester_id) {
    if (record.action === 'request.create') {
      memberQuery = memberQuery
        .in('role', ['owner', 'adult', 'co_parent'])
        .neq('user_id', record.actor_id);
    } else {
      memberQuery = memberQuery.eq('user_id', String(record.detail.requester_id));
    }
  } else if (record.actor_id) {
    memberQuery = memberQuery.neq('user_id', record.actor_id);
  }
  const { data: members, error: memberError } = await memberQuery;
  if (memberError) throw memberError;
  const userIds = (members ?? []).map((m) => m.user_id);
  if (userIds.length === 0) return Response.json({ sent: 0 });

  const { data: devices, error: deviceError } = await db
    .from('push_device').select('token').in('user_id', userIds);
  if (deviceError) throw deviceError;

  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });
  const accessToken = await auth.getAccessToken();
  if (!accessToken) return new Response('Could not authorize FCM', { status: 502 });
  const endpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  let sent = 0;
  for (const device of devices ?? []) {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: { title: copy[0], body: copy[1] },
          data: { event: record.action, space_id: record.space_id },
          android: { priority: 'high', notification: { channel_id: 'mhuri_family_updates' } },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    });
    if (response.ok) {
      sent++;
    } else {
      const errorBody = await response.text();
      if (errorBody.includes('UNREGISTERED') || errorBody.includes('NOT_FOUND')) {
        await db.from('push_device').delete().eq('token', device.token);
      }
    }
  }
  return Response.json({ sent });
});
