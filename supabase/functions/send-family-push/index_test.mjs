import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import test from 'node:test';

const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const pemKey = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();

let handler;
const envOverrides = {};
globalThis.Deno = {
  env: {
    get(name) {
      if (name in envOverrides) return envOverrides[name];
      return {
        PUSH_WEBHOOK_SECRET: 'test-webhook-secret',
        SUPABASE_URL: 'https://example.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
        FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
          project_id: 'mhuri-test',
          client_email: 'push@mhuri-test.iam.gserviceaccount.com',
          private_key: pemKey,
          token_uri: 'https://oauth2.googleapis.com/token',
        }),
      }[name];
    },
  },
  serve(fn) {
    handler = fn;
  },
};

await import('./index.ts');

test('rejects missing or invalid x-webhook-secret with 401', async () => {
  const noHeader = await handler(
    new Request('https://local.test/send-family-push', {
      method: 'POST',
      body: JSON.stringify({}),
    }),
  );
  assert.equal(noHeader.status, 401);

  const wrongHeader = await handler(
    new Request('https://local.test/send-family-push', {
      method: 'POST',
      headers: { 'x-webhook-secret': 'wrong-secret' },
      body: JSON.stringify({}),
    }),
  );
  assert.equal(wrongHeader.status, 401);
});

test('ignores deleted chat messages without querying membership', async () => {
  let fetched = false;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    fetched = true;
    return new Response('[]');
  };
  try {
    const res = await handler(
      new Request('https://local.test/send-family-push', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-webhook-secret': 'test-webhook-secret',
        },
        body: JSON.stringify({
          table: 'family_chat_message',
          record: {
            id: 'msg-1',
            space_id: 'space-1',
            sender_id: 'user-1',
            text: 'Secret removed text',
            deleted: true,
          },
        }),
      }),
    );
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { sent: 0, ignored: true });
    assert.equal(fetched, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('enforces invite_status=eq.active, excludes sender, delivers FCM, and prunes UNREGISTERED tokens', async () => {
  const calls = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    calls.push({ url, method: init.method ?? 'GET', body: init.body });

    if (url.includes('/rest/v1/membership')) {
      return Response.json([{ user_id: 'user-2' }, { user_id: 'user-3' }]);
    }
    if (url.includes('/rest/v1/push_device') && (init.method ?? 'GET') === 'GET') {
      return Response.json([{ token: 'tok-live' }, { token: 'tok-stale' }]);
    }
    if (url === 'https://oauth2.googleapis.com/token') {
      return Response.json({ access_token: 'fcm-oauth-token' });
    }
    if (url.includes('fcm.googleapis.com')) {
      const parsed = JSON.parse(String(init.body));
      if (parsed.message.token === 'tok-stale') {
        return new Response('{"error":{"status":"UNREGISTERED"}}', { status: 404 });
      }
      return Response.json({ name: 'projects/mhuri-test/messages/1' });
    }
    if (url.includes('/rest/v1/push_device') && init.method === 'DELETE') {
      return new Response(null, { status: 204 });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const res = await handler(
      new Request('https://local.test/send-family-push', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-webhook-secret': 'test-webhook-secret',
        },
        body: JSON.stringify({
          table: 'family_chat_message',
          record: {
            id: 'msg-2',
            space_id: 'space-abc',
            sender_id: 'user-1',
            sender_name: 'Mama',
            media_type: 'audio',
          },
        }),
      }),
    );

    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { sent: 1 });

    const membershipCall = calls.find((c) => c.url.includes('/rest/v1/membership'));
    assert.ok(membershipCall, 'membership query expected');
    const membershipParams = new URL(membershipCall.url).searchParams;
    assert.equal(membershipParams.get('space_id'), 'eq.space-abc');
    assert.equal(membershipParams.get('invite_status'), 'eq.active');
    assert.equal(membershipParams.get('user_id'), 'neq.user-1');

    const fcmCall = calls.find((c) => c.url.includes('fcm.googleapis.com'));
    const fcmPayload = JSON.parse(String(fcmCall.body));
    assert.equal(fcmPayload.message.notification.title, 'Mama');
    assert.equal(fcmPayload.message.notification.body, 'Sent a voice note.');

    const deleteCall = calls.find(
      (c) => c.url.includes('/rest/v1/push_device') && c.method === 'DELETE',
    );
    assert.ok(deleteCall, 'stale UNREGISTERED token must be deleted');
    assert.equal(new URL(deleteCall.url).searchParams.get('token'), 'eq.tok-stale');
  } finally {
    globalThis.fetch = originalFetch;
  }
});
