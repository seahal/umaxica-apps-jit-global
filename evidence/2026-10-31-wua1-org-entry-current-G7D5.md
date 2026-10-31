# WU-A1 current ORG sign-in entry and route classification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting application and tests.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/org/sign_ins_controller_test.rb` passed (8 runs, 63 assertions). This includes the six ORG sign-in IDs previously listed as failures in `plans/2026-10-28-baseline-failing-tests.md`.
- The classification guard and ORG sign-in files passed together (15 runs, 92 assertions, 0 failures, 0 errors, 0 skips). These tests use the current Auth admission transport and confirm the binding directly; they do not verify the complete Base confirmation browser journey.
- This supersedes the earlier six-failure observation for these current files only. It does not prove all WU-A1 Sentry boundaries, real provider login, deployment or full-suite acceptance. No application code was modified in this check.
