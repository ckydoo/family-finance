# Mhuri AI — Phase 1 Architecture (Ask Mhuri)

**Date:** 2026-10-23  
**Status:** Architecture Specification  
**Milestone:** Phase 1 — Read-Only Financial Assistant  

---

## 1. System Overview & Conceptual Flow

Mhuri AI follows a **server-mediated, tool-grounded architecture**. The client never communicates directly with third-party AI providers, and the AI model never queries raw database tables or executes arbitrary code.

```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter Client                        │
│                                                             │
│  [HomeScreen] ──> [AskMhuriScreen] ──> [AskMhuriController] │
│                                             │               │
│                                      [AiRepository]         │
│                                             │               │
│                                   [SupabaseSyncClient]      │
└─────────────────────────────────────────────┼───────────────┘
                                              │ POST /functions/v1/ask-mhuri
                                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Supabase Deno Edge Function                 │
│                     (functions/ask-mhuri)                   │
│                                                             │
│  1. Authentication: Verify Bearer JWT via /auth/v1/user     │
│  2. Authorization: Verify family membership & active role   │
│  3. Entitlement & Quota: Check daily usage (5 Free / 50 +)  │
│  4. Deterministic Financial Tools (Read-Only Allowlist):    │
│     - get_spending_summary                                  │
│     - get_budget_status                                     │
│     - get_category_breakdown                                │
│     - compare_spending_periods                              │
│     - get_upcoming_commitments                              │
│     - get_contributions_summary                             │
│  5. AI Provider Adapter (Gemini 2.5 Flash / Mock Provider)  │
│  6. Response Validator (Validates Typed Response Contract)  │
└─────────────────────────────────────────────┼───────────────┘
                                              │ Structured JSON Response
                                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Presentation                    │
│                                                             │
│  - Formatted Natural Language Answer                        │
│  - Grounded Financial Facts Card (Minor Units & Currency)   │
│  - Reporting Period & Freshness Badge                       │
│  - Suggested Follow-Up Chips                                │
│  - Safe Fallbacks & Insufficient Data Explanations          │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Server-Side Responsibilities (`ask-mhuri`)

### 2.1 Identity & Family Authorization
1. The Edge Function extracts the `Authorization: Bearer <token>` header and verifies it against `${baseUrl}/auth/v1/user`.
2. The caller's `user_id` is queried in `${baseUrl}/rest/v1/membership` alongside `family_id`.
3. If no active membership exists, the request is immediately rejected with HTTP 403 `FORBIDDEN_FAMILY_ACCESS`.

### 2.2 Entitlement & Quota Enforcer
1. The family's subscription status is checked in `public.family_entitlement`.
2. Active Plus status grants `50` queries per family per calendar day (UTC); Free status grants `5` queries.
3. Daily usage is recorded in `public.ai_usage_quota` via an atomic counter.
4. If the quota is exceeded, the function returns HTTP 429 `QUOTA_EXCEEDED` with reset timestamp.

### 2.3 Deterministic Financial Tools (Read-Only)
The model has access to a bounded allowlist of typed functions:
1. `get_spending_summary(family_id, period_start, period_end, currency)`:
   - Queries `transaction` where `space_id = family_id`, `type = 'expense'`, `deleted_at is null`, and transactions not linked to private accounts of other members.
   - Computes total minor units, count of transactions, largest expense, and average per transaction.
2. `get_budget_status(family_id, currency)`:
   - Queries active envelopes for the family.
   - Returns envelope name, limit, spent in active cycle, remaining amount, and utilization percentage.
3. `get_category_breakdown(family_id, period_start, period_end, currency)`:
   - Aggregates recorded expenses by envelope/category name.
4. `compare_spending_periods(family_id, current_start, current_end, previous_start, previous_end, currency)`:
   - Computes exact spending in both periods and the delta in minor units and percentage.
5. `get_upcoming_commitments(family_id, currency, horizon_days)`:
   - Queries `commitment_occurrence` and parent `financial_commitment` for upcoming due dates.
6. `get_contributions_summary(family_id, currency)`:
   - Aggregates savings goals contributions, campaign pledges, and debt repayments.

### 2.4 AI Provider Adapter
- **Primary Provider:** Google Gemini API (`gemini-2.5-flash` or `gemini-1.5-flash`).
- **Tool Calling:** Employs function declarations matching the deterministic financial tools above.
- **Mock Provider Mode:** When `GEMINI_API_KEY` is not configured or `MOCK_AI=true`, the adapter uses deterministic mock responses so that integration tests, local development, and offline test environments execute with 100% reliability.

---

## 3. Versioned Response Contract (`AiResponseContract`)

All responses returned to the client adhere to this JSON structure:

```json
{
  "contract_version": 1,
  "response_id": "ai_resp_01H...",
  "answer": "This month your family spent US$ 420.50 across 14 transactions, with Groceries being your largest expense.",
  "financial_facts": [
    {
      "label": "Total Spending",
      "minor_units": 42050,
      "currency": "USD",
      "formatted": "US$ 420.50"
    },
    {
      "label": "Largest Category",
      "value": "Groceries (US$ 215.00)"
    }
  ],
  "period": {
    "start": "2026-10-01T00:00:00Z",
    "end": "2026-10-23T23:59:59Z",
    "label": "October 2026"
  },
  "currency": "USD",
  "data_freshness": "2026-10-23T15:00:00Z",
  "suggested_questions": [
    "How much is left in our groceries budget?",
    "What were our biggest expenses this month?",
    "How does this compare to last month?"
  ],
  "limitations": [
    "Excludes transactions recorded on private accounts.",
    "Does not include unrecorded cash spending."
  ],
  "status": "success",
  "quota_remaining": 4,
  "quota_limit": 5
}
```

---

## 4. Flutter Client Architecture

### 4.1 Class Hierarchy
```
app/lib/
  core/
    ai/
      ai_models.dart            // AiQuestion, AiResponse, FinancialFact, etc.
      ai_repository.dart        // Invokes SupabaseSyncClient.invokeFunction('ask-mhuri')
  features/
    ai/
      ask_mhuri_screen.dart     // Main conversational UI
      ask_mhuri_controller.dart // StateNotifier/ChangeNotifier for conversation
      widgets/
        ai_message_bubble.dart  // Formatted message bubble
        ai_facts_card.dart      // Compact financial facts widget
        ai_suggestion_chips.dart// Suggested follow-up prompts
        ai_quota_banner.dart    // Daily quota indicator (Free vs Plus)
```

### 4.2 Home Screen Entry Point
- Placed on `HomeScreen` as a refined, subtle action card:
  - Title: **Ask Mhuri**
  - Subtitle: *Understand your family's finances*
  - Icon: Sparkle / AI icon in Mhuri theme palette (`context.primarySoft`, `context.primary`)
  - Tap: Navigates to `AskMhuriScreen`.

