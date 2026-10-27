# Mhuri AI — Future Phases (Design Only)

**Date:** 2026-10-23  
**Status:** Architectural Roadmap (Not Authorized for Implementation in Phase 1)  

---

## Phase 2 — Intelligent Insights
- Proactive spending anomaly detection.
- Month-over-month category trend analysis.
- Early warning alerts for envelopes pacing ahead of schedule.
- Home screen insight cards grounded in `FinancialHealthEngine` findings.

## Phase 3 — AI-Assisted Actions (Approval-Gated)
- Workflow:
  User Request &rarr; Structured Proposal &rarr; Pre-flight Verification &rarr; Human Approval &rarr; Final Server Re-validation &rarr; `BusinessOperationDispatcher.execute()` &rarr; Audit Record.
- Actions:
  - Prepare monthly budget allocations based on previous periods.
  - Generate shopping lists from recurring household needs.
  - Suggest chore / family task assignments.
- Safeguards:
  - Single-use confirmation tokens bound to operation ID.
  - No direct SQL execution; executes through existing application services.

## Phase 4 — Advanced Family Agent
- Multi-step financial planning workflows.
- Payday-to-payday optimization scenarios.
- Coordinated family budgeting with what-if scenario comparisons.
- Invariant: Autonomous money movement or payment execution remains strictly prohibited.

