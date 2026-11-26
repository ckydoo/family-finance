import assert from 'node:assert/strict';
import test from 'node:test';

let handler;
let finalizeQuotaReservation;
let openRouterModelsForPlan;
const envOverrides = {};
globalThis.Deno = {
  env: {
    get(name) {
      if (name in envOverrides) return envOverrides[name];
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

({ finalizeQuotaReservation, openRouterModelsForPlan } = await import('./index.ts'));

const askRequest = (question = 'Can we afford a $100 purchase?') =>
  new Request('https://local.test/ask-mhuri', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer test-user-token',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ family_id: 'family-1', question }),
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

test('tiered OpenRouter routing separates Plus and Free models', () => {
  assert.deepEqual(openRouterModelsForPlan(true), [
    'anthropic/claude-sonnet-4.6',
    'google/gemini-3.8-pro',
    'google/gemini-3.8-flash',
  ]);
  assert.deepEqual(openRouterModelsForPlan(false), [
    'google/gemini-3.8-flash',
    'openai/gpt-5-mini',
    'qwen/qwen3.8-flash',
  ]);
});

test('fast context RPC serves full answer without REST table waterfall and fails over from OpenRouter to Gemini', async () => {
  const originalFetch = globalThis.fetch;
  const originalInfo = console.info;
  const originalWarn = console.warn;
  const originalError = console.error;
  console.info = () => {};
  console.warn = () => {};
  console.error = () => {};
  envOverrides.OPENROUTER_API_KEY = 'openrouter-test-key';

  const seenUrls = [];
  globalThis.fetch = async (input) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    seenUrls.push(url);
    if (url.endsWith('/auth/v1/user')) {
      return Response.json({ id: 'user-owner-1' });
    }
    if (url.endsWith('/rest/v1/rpc/get_ask_mhuri_context')) {
      return Response.json({
        ok: true,
        role: 'owner',
        plus: true,
        daily_limit: 50,
        currency: 'USD',
        as_of: '2026-11-26T10:00:00Z',
        cycle_start: '2026-11-01',
        next_cycle_start: '2026-12-01',
        previous_cycle_start: '2026-10-01',
        cycle_spending: [{ currency: 'USD', minor_units: 22000 }],
        cycle_income: [{ currency: 'USD', minor_units: 120000 }],
        previous_cycle_spending: [{ currency: 'USD', minor_units: 18000 }],
        previous_cycle_income: [{ currency: 'USD', minor_units: 120000 }],
        account_balances_estimate: [{ currency: 'USD', minor_units: 78000 }],
        available_after_recorded_savings: [{ currency: 'USD', minor_units: 63000 }],
        member_spending: [
          { name: 'Tendai', is_you: true, currency: 'USD', spent_minor: 12000, tx_count: 1, share_percent: 55 },
          { name: 'Rudo', is_you: false, currency: 'USD', spent_minor: 10000, tx_count: 1, share_percent: 45 },
        ],
        budgets: [
          { name: 'Groceries', currency: 'USD', complete: true, limit_minor: 40000, spent_minor: 18000, remaining_minor: 22000 },
        ],
        top_categories: [
          { name: 'Groceries', currency: 'USD', spent_minor: 18000 },
        ],
        upcoming_commitments: [
          { name: 'Home Wi-Fi', currency: 'USD', due_date: '2026-11-28T00:00:00Z', amount_minor: 4500 },
        ],
        savings_goals: [],
        debts: [],
        shopping_summary: [{ currency: 'USD', open_items: 2, estimated_minor: 1500 }],
      });
    }
    if (url.endsWith('/rest/v1/rpc/reserve_ai_usage')) {
      return Response.json([{ status: 'ok', used: 2, reset_at: '2026-11-27T00:00:00Z' }]);
    }
    if (url.includes('openrouter.ai')) {
      return new Response('upstream overloaded', { status: 503 });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        model: 'gemini-3.8-pro',
        candidates: [{
          finishReason: 'STOP',
          content: {
            parts: [{ text: '**Yes — USD 485.00** remains after upcoming bills and a USD 100.00 purchase.' }],
          },
        }],
      });
    }
    if (url.endsWith('/rest/v1/rpc/finalize_ai_usage')) {
      return Response.json({ status: 'completed' });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const response = await handler(askRequest('Can we afford a $100 purchase?'));
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.provider, 'gemini');
    assert.equal(body.plan, 'plus');
    assert.equal(body.quota_limit, 50);
    assert.equal(body.quota_remaining, 47);
    assert.match(body.answer, /USD 485\.00/);
    // Verify zero table waterfall queries happened when fast RPC succeeded
    assert.equal(seenUrls.some((u) => u.includes('/rest/v1/transaction')), false);
    assert.equal(body.facts.member_spending.length, 2);
    assert.equal(body.facts.shopping_summary[0].open_items, 2);
    assert.equal(body.facts.purchase_scenario.fits_recorded_cash_estimate, true);
    assert.equal(body.facts.purchase_scenario.estimated_after_purchase_minor, 48500);
  } finally {
    delete envOverrides.OPENROUTER_API_KEY;
    globalThis.fetch = originalFetch;
    console.info = originalInfo;
    console.warn = originalWarn;
    console.error = originalError;
  }
});
