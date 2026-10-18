# Org control plane capability authorization: verification

Commit: `e423890e7357e1fa7975eac45aeacdb416b3bce9`, with uncommitted changes. The worktree also held
the user's unrelated pre-existing staged and unstaged changes, which were present during every run.

## Performed

- `bin/rails test` (full suite, second run after fixes): 11786 runs, 1 failure. The failure was
  `BranchCoverageBatch37ControllerArmsTest` (a stub that did not cover the new in-action Step-Up
  call). It was fixed and the file rerun passes (9 runs, 0 failures). The first full run's
  Inertia/preference contract failures came from frontend files being edited mid-run, which changes
  `ViteRuby.digest`; the same files pass when rerun.
- Targeted runs after the last change: `test/controllers/base/org/support/session_revocations_test.rb`
  24 runs, 0 failures (includes a Fetch Metadata cross-site CSRF case with forgery protection on);
  enforcement, IAM, console, membership, policy, and model tests all pass.
- `node node_modules/vitest/vitest.mjs run`: 87 files, 1054 tests, all passed.
- `node_modules/.bin/oxlint` on `src/features/org_admin` and the new pages: no findings.
  `tsc -p tsconfig.app.json --noEmit`: one error, in `src/pages/base/org/avatars/show.tsx`, a file
  this change does not touch.
- `bundle exec rubocop` on every changed Ruby and rake file: no offenses.
- `bin/rails zeitwerk:check`: passes.
- Migration `20260926120000_create_operator_capability_grants` applied and redone on the test
  database. `bin/rails db:migrate:org_zenith` in development fails on the earlier, unrelated
  `20260923170002 CreateOrgAuthorityResourceLifecycles` (unlogged-table constraint), so the
  development database was not migrated. `db/org_zenith_structure.sql` was edited by splicing the
  new table's DDL from a test-database dump.

## Not performed

- `operator_capabilities:bootstrap` was not run against a real database. It was loaded and listed
  with `bin/rails -T operator_capabilities`, and its model method is covered by tests.
- No real Step-Up ceremony was completed end to end. Integration tests set Step-Up columns on the
  session token, as the existing enforcement tests do, and assert the ceremony redirect separately.
- True concurrent revocation of the last IAM holder was not exercised. The row-locking path was
  tested sequentially, because transactional tests share one connection.
