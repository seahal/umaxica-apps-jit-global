# Home/Dashboard boundary and sign-in destination (P0)

Commit: 3b3163e655e91d967ba86174a7f24ee9dbb9c4cd, with uncommitted changes from this work. The
worktree also carried a pre-existing, unrelated edit to `config/environments/development.rb`
(`consider_all_requests_local = true`) that this work did not touch.

## Reproduction before the fix

- `test/integration/social_auth_login_test.rb`: ordinary Google and Apple social sign-in landed on
  path `/` (Expected "/dashboard", Actual "/").
- `test/controllers/base/{app,com,org}/roots_controller_test.rb`: authenticated `GET /` and
  anonymous `GET /dashboard` reported `ActiveRecord::RecordNotFound` from the controller.

## Results after the fix

- `bundle exec rails test` (no extra ENV): 12544 runs, 0 failures, 0 errors, 2 skips, exit 0.
- `COVERAGE=true bundle exec rails test`: 12546 runs, 0 failures; SimpleCov gate failed (exit 2):
  line 96.27% / 98%, branch 74.93% / 93%, method 92.07% / 97%. The gate was already failing before
  this work (evidence/2026-09-26-* records line 95.96%); no baseline run at this commit was made.
- `bundle exec rubocop` on changed Ruby files: 3 offenses, all `Style/ImplicitRuntimeError` on
  pre-existing, unchanged lines in `base/{app,com,org}/roots_controller.rb`.
