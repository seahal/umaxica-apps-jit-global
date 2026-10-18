# Integrated authentication implementation acceptance ledger

- Date: 2026-10-09 UTC.
- Reviewed HEAD: `c9fdaf813e15d4b2680375b71e2b1054cf313c04`; worktree dirty with in-scope app social changes, tests, schema dumps, and unrelated concurrent edits. The final whole Rails run began before two documentation-only commits (`c4d85867...` and `c9fdaf81...`), neither of which touched application, migration, or test files. Two T07 tests were added afterward and run separately.
- Frozen source: `sha256sum one.md` returned `b31af898ade48669576ec0259127724dc02ee4c351893b83b5eda6c421bd0934`, matching `four.md`.
- Verdict: **CHANGES REQUIRED**. The current worktree does not prove the frozen Definition of Done. Eight implementation task entries remain unchecked, including the Phase 16 attack/failure and CSRF-result matrices, the Phase 19 OTP parity matrix, and the Phase 23 fault matrix. Passing broad tests cannot substitute for those required guarantees. The separate app social defect recorded as T16 FAIL in `2026-10-09-auth-acceptance-repair-H9K4.md` was repaired and is now a passing slice, not a whole-contract T16 pass.

## Findings and acceptance conditions

1. **Required attack and failure coverage remains incomplete (Tasks 16.1, 16.3, 16.5, 16.6, 19.3, 19.4, 23.1, 23.3; T03, T05, T11–T17).** The current `two.md` retains eight `[ ]` entries. The public-boundary selections and whole suite pass, but no completed matrix demonstrates every specified wrong-browser, CSRF/result, OTP parity, capacity, replay, failure-ordering, and cleanup case. Acceptance requires the named matrices to execute and their outcomes to be reconciled against code and the frozen contract. The user-approved deferral of redeemed OIDC admission cancel-and-start is recorded as a deviation rather than silently treated as verified behavior.
2. **RP regression groups are not individually established (RP1–RP14).** Existing RP tests were included in the whole suite, but this review has not completed a guarantee-level code-and-test trace for each of the 14 groups. Acceptance requires a mapped result for each group; a green suite is indirect evidence only. Real browser cookie/CSP and external edge behavior remain deployment/environment verification limits and are reported separately.
3. **The repository schema-drift top-level gate cannot be recorded as passing in this dirty worktree (Task 23.4 gate).** Both relevant generated dumps matched the current disposable PostgreSQL catalogs through `SchemaDriftVerification.dump_matches?`. The top-level `db:verify_no_schema_drift` task intentionally treats modified tracked dumps as drift. Its exit-0 condition requires a clean reviewed schema baseline; no bypass or false pass was used.

The app social Source audit, stale callback/grant, and withdrawal repairs are described and verified in [the scoped evidence](2026-10-09-social-release-acceptance-Q4P7.md). App Apple/Google termination retains a keyed release proof. Org Microsoft Entra ID was not modified; the user explicitly required that company-owned Entra authority not be automatically unlinked by this app change. The user also approved D-53 live RP revocation checks, D-117/D-118, the D-110 test-helper exception, and the stated OIDC deferral. Those approvals do not prove the remaining tests.

## Coverage ledger

`PASS` means the named guarantee has a current code-and-test trace in this review or the linked preceding evidence. `PARTIAL` means a material slice was exercised but the whole guarantee is not established. `NOT VERIFIED` means the whole suite ran but no sufficient guarantee-level trace was completed.

| ID | Status | Evidence or remaining condition |
| --- | --- | --- |
| T01 | PASS | Effective contact constraints and public candidate/finalizer tests; prior acceptance repair evidence. |
| T02 | PASS | Separate-backend signed contact races, database cardinality constraints, and Source intent assertions; prior evidence. |
| T03 | PARTIAL | App/com real/dummy receipt and cancellation parity measured; full Phase 19 external-shape and dummy-impossibility matrix remains. |
| T04 | PASS | Two-browser resend isolation and common attempt limits; prior evidence. |
| T05 | PARTIAL | App social login/signup/link now reject old grants after release or termination, including a retained keyed proof; contact release paths and a complete cross-surface replay/race matrix remain. |
| T06 | PASS | Existing social subject at signup signs in; unknown sign-in creates no account or email link; prior evidence and whole suite. |
| T07 | PARTIAL | New independent-backend races prove one Google subject owner and one Google/Apple binding per Client; org Entra provisioning rejects an app Client ID. Full callback/route-level org Customer refusal has not been separately traced. |
| T08 | PASS | Secret lookup is selected-Identity scoped even for equal values; prior evidence. |
| T09 | PASS | Manual Secret issuance and one-root claim races; prior evidence. |
| T10 | PASS | A=0..20 presentation and issuance counts; prior evidence. |
| T11 | NOT VERIFIED | Complete competing reserve/cancel/consume capacity matrix not traced. |
| T12 | NOT VERIFIED | All absence, expiry, replay, delivery failure, and back/reload presentation boundaries not traced. |
| T13 | NOT VERIFIED | Signed WebAuthn negative and slot-concurrency matrix not traced as one guarantee. |
| T14 | PARTIAL | Step-up and management refusal slices pass; full grant/challenge/reservation and Secret-session proof remains. |
| T15 | PARTIAL | Voluntary passkey deletion races pass; retained paths and forced-revocation distinctions need full trace. |
| T16 | PARTIAL | Social Source outbox rollback, Chronicle retry/idempotency, and unlink replay pass; full Phase 23 injected-failure matrix remains. |
| T17 | NOT VERIFIED | All other-surface, cooldown, logout, limit, and Base/Auth boundary regressions need one mapped ledger. |
| RP1 | PARTIAL | Controller/authority structural inventory exists; complete boundary trace remains. |
| RP2–RP10 | NOT VERIFIED | Fallback, refresh, cookies, callback, UserInfo, binding, and logout groups lack individual guarantee-level mapping. |
| RP11 | PARTIAL | No active Side token in structural inventory; Warp rename behavior not fully traced. |
| RP12–RP14 | NOT VERIFIED | Discovery, Core edge/Rails split, and Palm public-client/PKCE/bearer guarantees lack individual mapping. |

## Executed checks and limits

- Full Rails suite on 20 verified disposable databases: 14,950 runs, 127,023 assertions, 0 failures/errors/skips. A later focused social/T07 selection passed 16 runs, 63 assertions, 0 failures/errors/skips. A later behavior-equivalent released-subject SQL query refinement passed 15 runs, 76 assertions, 0 failures/errors/skips. The new tests and query refinement are not included in the earlier full-suite count.
- `bundle exec rubocop --parallel`: 5,314 files, no offenses. `bun run test`: 99 files and 1,140 tests passed. `bun run format:check`, `bun run lint`, `bun run typecheck`, `bun run build`, `bin/rails zeitwerk:check`, and `git diff --check` exited 0.
- App Zenith and Chronicle disposable catalog dumps matched the tracked SQL through the repository's schema-normalization verifier. The two release-proof migrations were reversed successfully in a separate disposable catalog. `db:verify_no_schema_drift` exit 0 is unverified for the dirty worktree; no shared database, provider account, deployment target, or GitHub state was changed.
- Browser E2E, real identity-provider exchange, real cookie/SameSite/CSP enforcement, shared-database deployment, and operational Chronicle retention were not exercised. These deployment limits are separate from the local implementation verdict.

The current social implementation, focused tests, migrations, diagrams, and scoped spec agree for the behavior they cover. The integrated implementation, tests, and documents are not yet reconciled against every frozen acceptance clause; `two.md` itself still records eight unfinished tasks.
