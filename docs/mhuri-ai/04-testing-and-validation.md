# Mhuri AI — Testing & Validation Plan

**Date:** 2026-10-23  
**Status:** Verification Suite  

---

## 1. Test Levels & Strategy

### 1.1 Unit & Contract Tests (Flutter)
1. **Model & Serialization:** Verify JSON parsing of `AiResponseContract`, `FinancialFact`, and error states.
2. **Quota Handling:** Verify UI behavior when `quota_remaining == 0` or HTTP 429 is received.
3. **Currency & Minor Units:** Verify that financial facts display formatted strings with proper currency symbols and thousand grouping without rounding errors.
4. **Offline Handling:** Verify that when offline, Ask Mhuri shows an informative offline banner and disables request dispatch without crashing.

### 1.2 Widget & Interaction Tests (Flutter)
1. **Welcome Screen:** Verify example questions display and tapping one enters it into the input field or sends it.
2. **Conversation Flow:** Verify typing an input, seeing the progress/typing indicator, and rendering the response bubble with structured financial facts.
3. **Home Entry Point:** Verify the "Ask Mhuri" card renders on `HomeScreen` and tapping it navigates to `AskMhuriScreen`.
4. **Keyboard & Responsive Layout:** Verify that on narrow screens or with keyboard visible, the message list scrolls properly without RenderFlex overflow.

### 1.3 Backend & Mock Provider Tests (Supabase / Deno)
1. **Authentication Gate:** Requests without JWT or with invalid token receive 401.
2. **Membership Gate:** Requests for a space where caller is not a member receive 403.
3. **Quota Cap:** Consecutive requests beyond the limit return 429.
4. **Deterministic Calculation Integrity:** Tools return identical numbers to client calculation engines (`FinancialHealthEngine`).

### 1.4 Regression Suite
- Run full suite `flutter test` (all 445 existing tests must pass).
- Run `flutter analyze --fatal-infos` (0 warnings).

