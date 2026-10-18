# Browser RP binding TDD verification

Date: 2026-10-14

Commit under test: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`

The worktree was already dirty before this verification (`1021` porcelain entries at the time of
recording). The verification preserved that worktree and changed only the Browser RP logout slice
and its contract tests. No raw proof, cookie, token, or request credential is retained here.

## Scope

The slice adds version-one Browser RP binding data to `AcmeLogoutTransaction` in the existing
`app_ticket` database, binds authority work to the parent Device Session, refresh family, and
current root generation, stores the raw browser proof only in the encrypted Rails session map,
requires the proof on every unfinished origin POST (including retry after a partial failure), and
enforces the registered `/sign/out/completion` destinations. Repeated starts reuse the same
unfinished intent for the same RP session.

## Database verification

Only the ordinary test and development databases were used. `POSTGRESQL_ISOLATED_TEST_RUN_ID` was
unset for every Rails command below.

- `RAILS_ENV=test bin/rails db:migrate:app_ticket` exited 0.
- `RAILS_ENV=development bin/rails db:migrate:app_ticket` exited 0.
- A runner inspection against each ordinary `app_ticket` database reported the seven binding
  columns: `binding_version`, `realm`, `parent_session_ref`, `captured_root_ref`,
  `root_refresh_family_ref`, `captured_root_generation`, and `origin_intent_digest`.
- The same inspection reported the two validated constraints:
  `acme_logout_transactions_binding_version` and
  `acme_logout_transactions_browser_rp_binding_shape`.

## Verification results

- Focused Browser RP/model/coordinator/base/palm/tech/matrix tests before the final retry-guard-only
  change: 55 runs, 944 assertions, 0 failures, 0 errors, 0 skips.
- Authority-first flow, including partial-failure proof retry refusal: 5 runs, 184 assertions, 0
  failures, 0 errors, 0 skips.
- Logout/RP regression set: 392 runs, 2,217 assertions, 0 failures, 0 errors, 0 skips.
- Vitest: 100 files, 1,156 tests passed.
- TypeScript `tsc --build`: passed.
- RuboCop on the 18 changed production/test files: no offenses. The final guard and authority test
  were rechecked after the security review with no offenses.
- Ruby syntax checks for the changed concerns, coordinator, controllers, and migration: all
  `Syntax OK`.
- `git diff --check` on the changed tracked files: passed.

The full Rails suite was not rerun in this verification. Existing unrelated strict-loading/avatar
environment coverage remains outside this slice.
