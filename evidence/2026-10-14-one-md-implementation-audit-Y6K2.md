# one.md implementation audit

Recorded 2026-10-14 against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on `feature`.
The worktree contained 1,058 changed or untracked paths. The frozen plan files remain unchanged:

- `one.md`: `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`
- `two.md`: `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`

This audit uses the plan's fixed implementation order and the current evidence, code and test
results. All database-backed checks in this cycle used the ordinary Rails development/test
databases; `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset. No database reset, migration replay,
backfill, cutover, bulk mutation or external write was performed.

| Plan area | Current state | Evidence or limiting condition |
| --- | --- | --- |
| S0 authority, preparation, Device Sign In retirement, environment-test retirement and Xper retirement | Local implementation and regression evidence complete | `evidence/2026-10-13-xper-standard-test-followup-R6M3.md`, `evidence/2026-10-14-step5-acceptance-reconciliation-H7V4.md` and focused suites |
| BCL removal (REQ-007) | BLOCKED | Standard development queue has zero pending first-party delivery jobs, but a production/external consumer map and confirmation are unavailable; removing the sender/receivers would violate the plan's precondition. `evidence/2026-10-13-bcl-queue-inventory-K2V9.md` |
| Routing policy and annotations | Local implementation complete | Before/after route inventory and FIXME checks are recorded in `evidence/2026-10-13-routing-annotations-step16-H8Q3.md` |
| Frozen String (REQ-039) | PARTIAL/BLOCKED | Ten `bin/` launchers still lack directives and `.github`/`bin` are read-only mounts; migration replay requires the isolated fleet. The checker reports the ten files. `evidence/2026-10-14-frozen-string-directives-followup-Q3M7.md` |
| Railties | PARTIAL | Subscriber and CI eager-loading behavior are implemented and locally tested. Production deprecation output remains unverified because the required `TRUSTED_PROXIES` and production configuration were not available; REQ-044 is explicitly on hold. `evidence/2026-10-13-railties-R8C2.md` |
| Jump | Local compatibility implementation complete; release acceptance open | The pinned 0.4.0 candidate is release-blocked and deployed interoperation/browser acceptance is unavailable. `evidence/2026-10-13-jump-step10-4JQ2.md` |
| S2 authentication-path audit | Local audit complete | Writer-role, expiry, refresh and fail-closed paths are covered; live outage and external-provider behavior remain outside the local run. `evidence/2026-10-14-auth-path-step11-post-palm-tech-J8Q4.md` |
| S3 shared sign-out and S4 completion matrix | Local transaction, authority, CSRF and completion behavior implemented and regression-tested | Browser/manual acceptance, external IdP flow and BCL removal remain release gates. The sign-out/refresh deadlock and Browser RP writer leak were corrected and repeatedly verified. `evidence/2026-10-14-signout-refresh-deadlock-fix-R7P4.md`, `evidence/2026-10-14-browser-rp-writer-resource-N6H2.md` |
| Palm Browser RP/native retirement and Tech RP | Local routes, policies, registrations, migrations and tests complete | Real browser, external key/DNS/deployment and production consumer acceptance are not available. `evidence/2026-10-14-auth-path-step11-post-palm-tech-J8Q4.md` and `evidence/2026-10-13-tech-palm-browser-rp-logout-M5Q8.md` |
| Avatar R0–R5 follow-up | PARTIAL/BLOCKED | Ledger, grants, local authority and post-marker behavior are covered. AV-3/AV-6 committed races and MIG-2/MIG-4 migration/cutover require run-owned workers or a disposable fleet, which the standard-DB-only instruction forbids. `evidence/2026-10-14-avatar-shared-test-db-gate-V3K9.md` |
| Strict Loading | Diagnostic complete; acceptance not clean | Test mode is `true/:all/:raise`; focused preloading works and the current full run has no Strict Loading errors, but the required diagnostic/full acceptance is not green because the suite still has the known Avatar and structure-dump failures. `evidence/2026-10-14-strict-loading-post-correction-K6V2.md`, `evidence/2026-10-14-full-after-deadlock-writer-H8M4.md` |
| Governance (REQ-076) | UNVERIFIED | The frozen requirement asks for an independent reviewer session that did not author the reviewed text. The current review was performed in this implementation session, so it cannot be claimed as that independent audit. |
| Full suite | Non-clean for known constraints only | 15,274 runs / 129,162 assertions / 3 structure-dump failures / 14 Avatar worker-receipt errors / 0 skips. The previously observed Recovery Secret error and sign-out/refresh deadlock are absent. `evidence/2026-10-14-full-after-deadlock-writer-H8M4.md` |

The current state leaves no independent application change that can be completed safely using only
the normal Rails development/test databases. The remaining rows require an external consumer or
production fact, a writable mount, a disposable migration/worker fleet, or user-owned browser and
deployment acceptance. `one.md` and `two.md` were not edited to conceal those conditions.
