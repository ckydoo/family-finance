# Mhuri AI — Release Readiness Gate

**Date:** 2026-10-26  
**Status:** Implementation complete; release setup and verification pending  

---

## 1. Safety & Entitlement Controls
- Feature Flag: `MHURI_AI_ENABLED` defaults off unless explicitly set to `true`.
- Server-Side Kill Switch: `ask-mhuri` rejects requests while `MHURI_AI_ENABLED` is off.
- Provider Secrets: `GEMINI_API_KEY` is read only by the Edge Function and must be stored in Supabase Secrets; it is never placed in Flutter.

## 2. Verification Checklist
- [x] Baseline audit complete (`00-existing-system-audit.md`).
- [x] Architecture design complete (`01-phase-1-architecture.md`).
- [x] Security & permission matrix documented (`02-security-and-permissions.md`).
- [x] Database migration prepared (`03-database-changes.md`).
- [x] Testing plan established (`04-testing-and-validation.md`).
- [x] Future phases bounded and isolated (`05-future-phases.md`).
- [x] Backend implementation of `ask-mhuri` Edge Function with family-scoped financial summaries and server-side quota checks.
- [x] Flutter `SyncEngine.askMhuri` client call.
- [x] Flutter `AskMhuriScreen` UI and `HomeScreen` entry point.
- [ ] Apply migration `054_mhuri_ai_quota.sql`, configure provider secrets, and deploy/enable the Edge Function.
- [ ] End-to-end tests passing.
- [ ] Full regression suite passing.

