import assert from 'node:assert/strict';
import test from 'node:test';

let handler;
let finalizeQuotaReservation;
globalThis.Deno = {
  env: {
    get(name) {
      return {
        MHURI_AI_ENABLED: 'true',
        SUPABASE_URL: 'https://example.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: 'service-test-key',
        GEMINI_API_KEY: 'gemini-test-key',
      }[name];
    },
  },
  serve(value) {
    handler = value;
  },
};

({ finalizeQuotaReservation } = await import('./index.ts'));

const askRequest = () => new Request('https://local.test/ask-mhuri', {
  method: 'POST',
  headers: {
    Authorization: 'Bearer test-user-token',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ family_id: 'family-1', question: 'Can we afford this?' }),
});

test('auth-service timeouts return a controlled retryable response', async () => {
  const originalFetch = globalThis.fetch;
  const originalError = console.error;
  globalThis.fetch = async () => {
    throw new DOMException('The operation was aborted due to timeout', 'TimeoutError');
  };
  console.error = () => {};
  try {
    const response = await handler(askRequest());
    assert.equal(response.status, 504);
    assert.deepEqual(await response.json(), { error: 'AI_REQUEST_TIMEOUT' });
  } finally {
    globalThis.fetch = originalFetch;
    console.error = originalError;
  }
});

test('invalid sessions remain an authentication error', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response('{}', { status: 401 });
  try {
    const response = await handler(askRequest());
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: 'NOT_AUTHENTICATED' });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('quota finalization retries a lost response idempotently', async () => {
  let calls = 0;
  const committed = await finalizeQuotaReservation(async () => {
    calls += 1;
    if (calls === 1) throw new TypeError('connection reset after commit');
    return Response.json({ status: 'completed', already_finalized: true });
  });
  assert.equal(committed, true);
  assert.equal(calls, 2);
});

test('quota finalization fails closed on released or missing reservations', async () => {
  const released = await finalizeQuotaReservation(async () =>
    Response.json({ status: 'released' }));
  assert.equal(released, false);

  let calls = 0;
  const unavailable = await finalizeQuotaReservation(async () => {
    calls += 1;
    return new Response('{}', { status: 503 });
  });
  assert.equal(unavailable, false);
  assert.equal(calls, 2);
});
