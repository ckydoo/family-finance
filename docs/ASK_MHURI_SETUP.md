# Ask Mhuri: implementation and release setup

Ask Mhuri is implemented as a read-only family financial assistant. The app sends a question and up to six recent conversation turns to the `ask-mhuri` Supabase Edge Function. The server verifies the signed-in family member, excludes private accounts from shared answers, builds a bounded financial summary, enforces the family’s daily question allowance, and calls OpenRouter. The function requests zero-data-retention and denies providers that collect request data. The model provider still processes the request to produce an answer, and its terms apply. Chat history is stored locally on the device, scoped to the signed-in user and active family space; it does not sync between devices or family members. Users can start a new chat, reopen, rename, and delete saved chats.

## Included in this change

- A Home entry and a focused chat screen with example decision questions, visible allowance, grounded figures, and a contextual Plus link.
- Free allowance: 5 questions per family per UTC day. Active Plus allowance: 50 per family per UTC day.
- A family-scoped, atomic usage counter in migration `054_mhuri_ai_quota.sql`.
- Server-side authorization, financial summarization, private-account exclusion, and bounded read-only provider requests in `supabase/functions/ask-mhuri/index.ts`.
- Ask Mhuri included in the Plus entitlement on new verifications and existing active entitlements.
- In-app and web privacy disclosures for OpenRouter and the routed model provider.

## Required before the feature can answer real questions

The Edge Function is fail-closed until explicitly configured. Before release:

1. Apply migration `054_mhuri_ai_quota.sql` to the intended Supabase project.
2. Add `OPENROUTER_API_KEY` as a Supabase function secret. The function routes through `deepseek/deepseek-v4.1-flash-1017`, then `qwen/qwen3.8-flash`, then `google/gemini-3.8-flash`. OpenRouter's provider routing is restricted to zero-retention endpoints that deny data collection. Gemini is retained as a fallback if the OpenRouter key is absent in an environment.
3. Deploy the function: `supabase functions deploy ask-mhuri`.
4. Enable it for the intended rollout by setting `MHURI_AI_ENABLED=true` as a function secret or environment variable.
5. Confirm the privacy notice, provider terms, usage cap, and Plus wording for the target release and markets.

Do not enable the function in a release until the migration and provider secret are configured. A missing flag or both provider secrets returns a clear unavailable response; no demo financial answers are fabricated.

## Current boundaries

- The assistant answers from recorded shared family data only. It cannot move money, create transactions, edit budgets, or message family members.
- Private/personal accounts and their transactions are excluded from the server summary.
- Teen and child roles are denied by the first release; age-appropriate coaching needs a separate design and consent boundary.
- Affordability and savings responses are estimates. Unrecorded cash, outside accounts, and future changes may be missing.
- The daily cap resets at midnight UTC and is shared by every member of a family space.
- Conversations remain on the current screen only and are not persisted by Mhuri.
