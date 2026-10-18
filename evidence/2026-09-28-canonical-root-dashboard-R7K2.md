# Canonical root Dashboard for Base and Warp app/com/org

- Commit: `f8c93e4a9a50e22a942976a5810962f039662206`, with uncommitted changes that make up this change (the result depends on them).
- ADR: `adr/base-warp-canonical-root-dashboard.md`.

## Checks performed

- `bin/rails test test/controllers/base test/integration/routes`: after the Base change, all passed
  except 6 avatar-image tests that fetched the Dashboard via `/dashboard`. Those were pointed at `/`
  and then passed (16 runs, 0 failures).
- `bin/rails test test/controllers/warp test/integration/warp_sso_start_contract_test.rb test/integration/routes`:
  189 runs, 0 failures.
- `bin/rails test test/controllers/base/{app,com,org}/sign_outs_controller_test.rb`: 19 runs, 0 failures.
- `bin/rails test` (full suite): 12073 runs, 77360 assertions, 0 failures, 0 errors, 2 skips. The
  2 skips were already there before this change.
- `rubocop` on changed Ruby files: 4 offenses. The same 4 appear on the unchanged files at HEAD.

## Observation

Before this change, Warp `GET /dashboard` returned 200 for a correctly signed access token whose
session public id has no session record. A probe test run on the stashed worktree showed this.
Warp `/` now behaves the same way, because it uses the same `logged_in?`. Base `/` renders Home for
that credential.
