# Implementation pause notes

- P1–P9 phase commits are on `feature` with per-phase pushes.
- See `evidence/2026-09-13-auth-boundary-consolidation.md` for executed checks and remaining gaps.
- Highest-priority follow-ups:
  1. Cut OIDC authorization-code exchange over to Valkey AuthorizationCodeStore and retire
     PostgreSQL AuthorizationCode tables/models.
  2. Retire deprecated shared browser clients after seven RP flows are fully wired.
  3. Migrate Auth ceremony controllers onto AuthCeremonySession + OpaqueAdmissionStore.
  4. Run full Rails suite + SimpleCov and browser history tests; refresh evidence.
