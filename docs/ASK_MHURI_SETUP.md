# Ask Mhuri: implementation and release setup

Ask Mhuri is implemented as a read-only family financial assistant. The app sends a question and up to six recent in-memory conversation turns to the `ask-mhuri` Supabase Edge Function. The server verifies the signed-in family member, excludes private accounts from shared answers, builds a bounded financial summary, enforces the family’s daily question allowance, and calls Google Gemini. It does not save conversations in Mhuri. The provider request uses `store: false`.

## Included in this change

- A Home entry and a focused chat screen with example decision questions, visible allowance, grounded figures, and a contextual Plus link.
- Free allowance: 5 questions per family per UTC day. Active Plus allowance: 50 per family per UTC day.
- A family-scoped, atomic usage counter in migration `054_mhuri_ai_quota.sql`.
- Server-side authorization, financial summarization, private-account exclusion, and bounded read-only provider requests in `supabase/functions/ask-mhuri/index.ts`.
- Ask Mhuri included in the Plus entitlement on new verifications and existing active entitlements.
- In-app and web privacy disclosures for optional Google Gemini processing.

## Required before the feature can answer real questions

The Edge Function is fail-closed until explicitly configured. Before release:

1. Apply migration `054_mhuri_ai_quota.sql` to the intended Supabase project.
2. Add the `GEMINI_API_KEY` as a Supabase function secret. The model is set by `GEMINI_MODEL`; the default is `gemini-3.8-flash`.
3. Deploy the function: `supabase functions deploy ask-mhuri`.
4. Enable it for the intended rollout by setting `MHURI_AI_ENABLED=true` as a function secret or environment variable.
5. Confirm the privacy notice, provider terms, usage cap, and Plus wording for the target release and markets.

Do not enable the function in a release until the migration and provider secret are configured. A missing flag or secret returns a clear unavailable response; no demo financial answers are fabricated.

## Current boundaries

- The assistant answers from recorded shared family data only. It cannot move money, create transactions, edit budgets, or message family members.
- Private/personal accounts and their transactions are excluded from the server summary.
- Teen and child roles are denied by the first release; age-appropriate coaching needs a separate design and consent boundary.
- Affordability and savings responses are estimates. Unrecorded cash, outside accounts, and future changes may be missing.
- The daily cap resets at midnight UTC and is shared by every member of a family space.
- Conversations remain on the current screen only and are not persisted by Mhuri.
