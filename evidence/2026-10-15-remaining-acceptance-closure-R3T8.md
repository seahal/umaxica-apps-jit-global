# Remaining in-container acceptance work and Avatar closure

- Base: `37d277550` on `feature`; commits `9c3394dca`, `1542869e4`, `ba71260b9` add tests only. The
  worktree also held the user's own uncommitted `AGENTS.md` change and untracked `DESIGN.md`, which
  were not touched and do not affect these results.
- Actor: Claude Opus 5.5 (claude-opus-5-5). Standard Rails test database only; isolated-fleet cases
  are EXCLUDED by `three.md` CHG-009. No push, reset or external write.

## Results

| Case   | Result                                                                        | Observation                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------ | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AT-001 | PASS (automated); user browser check remains                                  | `test/integration/oidc_rp_logout_sibling_scope_test.rb`, 6 runs, 0 failures: zero, one and several siblings revoked with the parent, another parent intact, an already-revoked historical row keeps its `revoked_at` and status, and a Warp sibling refuses its unexpired access and refresh credentials and clears both cookies (positive control accepted before sign-out).                                      |
| AT-008 | PASS (automated); user browser check remains                                  | `test/integration/browser_rp_parent_state_fail_closed_test.rb`, 3 runs, 0 failures: an unreadable Ticket writer answers 503 no-store with no protected page; a revocation committed between requests inside `ActiveRecord::Base.cache` is refused. Executed: the test reading role uses `test_app_ticket_replica_db`, the writing role `test_app_ticket_db`, so the positive control proves writer reads.          |
| AT-010 | PASS                                                                          | `JumpRtSurface::ISSUER_NAMESPACES` lists 13 nodes without Tech; no Tech back-channel route; Tech takes part in parent revocation (AT-001 matrix and Tech revocation tests).                                                                                                                                                                                                                                        |
| AT-011 | PASS (automated); user browser check remains                                  | `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb`, 57 runs, 0 failures, for all 12 first-party clients through their own realm Base authority: global sign-out with sibling, IdP session absent, resubmission, failure after COMMIT; different account for app and org realms. The com realm has one Visitor fixture, so its different-account case is covered only by the Core com integration test. |
| AT-017 | PASS                                                                          | `adr/xper-rails-surface-retirement.md` states the supersession, no replacement surface, no model/schema/record change, Edge transfer separate, Web Push preserved; both historical ADRs carry the supersession note.                                                                                                                                                                                               |
| AT-024 | PASS for automated checks; published-JWKS limit violation not observable here | Development refuses any external surface keyset at boot (`JWT_AUTH_APP_PUBLIC_KEYSET must not be set in development`, exit 1, for a duplicate-kid and a non-JSON value). The 1..4 key, unique-kid and 65,536-byte checks in `JitSecurityJwtRegistry.validate_jump_issuer_records!` run only with production key material, which is not available.                                                                  |
| AT-074 | PASS                                                                          | Routing ADR and `.agents/harnesses/rules/generic/routing.mdc` both define A/B/C; the exception ledger records the `/sign` and `/sign/out/completion` rows; `param:` is existing debt and prohibited for new routes.                                                                                                                                                                                                |
| AT-075 | PASS                                                                          | 14 route FIXMEs, all `FIXME: [routing] <reason>`; every `param:` route definition carries one (the seven other `param:` matches are explanatory comments).                                                                                                                                                                                                                                                         |
| e2e    | BLOCKED                                                                       | `e2e/app-secret-sign-in-entry.spec.ts` requires `E2E_ISOLATED_RAILS_RUNNER` and a Jump origin; the isolated runner is retired.                                                                                                                                                                                                                                                                                     |

## AT-073 — Avatar closure

| Area                                   | Result   | Basis                                                                                                                                   |
| -------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 1 Writers and readers (AV-1, AV-8)     | PASS     | Ledger `evidence/2026-10-14-avatar-ownership-consumer-ledger-A7Q4.md`; post-marker behavior in the cutover operation and barrier tests. |
| 2 Concurrency (AV-3, AV-6)             | EXCLUDED | Independent-connection COMMIT tests need run-owned workers (CHG-009).                                                                   |
| 3 HTTP authority (AV-5)                | PASS     | APP and ORG transfer controller tests, including replay.                                                                                |
| 4 Grants (AV-7)                        | PASS     | `avatar_access_grants_test`, membership and policy tests.                                                                               |
| 5 Migration and cutover (MIG-2, MIG-4) | EXCLUDED | Disposable fleet (CHG-009). Drafts stay outside `migrations_paths`; applied migrations differ only by the frozen directive.             |

Regression: Avatar tests (75 files) 467 runs, 0 failures, 14 errors, all the excluded guard. AV-4
and AV-9 sequential cases pass; AV-2 real-COMMIT cases and MIG-3 are EXCLUDED with the fleet.
Production cutover, personal-data policy, legacy-structure removal, physical deletion and MIG-1 as a
whole stay EXCLUDED; no Avatar identifier, reference or history was changed. No in-scope area is
closed on a stated gap. AT-073: closed with the exclusions above.

## Still outside this environment

- User browser acceptance (AT-001, 004, 006, 008, 009, 011, 025, 078).
- Production-like boot with real key material (AT-015, AT-024 limits, AT-029 output).
- Production queue inspection for removed BCL jobs (AT-007).
- Deployed Jump interoperation; whether Palm native apps are in use.
- AT-076 independent review and AT-077 earlier `[CHECKPOINT]` commits: user decisions.
