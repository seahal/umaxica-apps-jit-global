# WU-4 shared authentication test setup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes, including the test setup edits, affected the results.
- Updated the shared test setup for the explicitly requested Rails test repair: removed deleted Visitor admission, transaction, contact and token branches, and stopped enabling the removed corporate sentry flags. Remaining app and org branches were preserved.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/org_oidc_auth_handoff_root_completion_test.rb`: 4 runs, 215 assertions, no failures, errors or skips. Before this edit the same file had four errors from `VisitorAuthAdmissionBinding`.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/up/telephones_controller_test.rb test/integration/social_login_admission_test.rb`: 63 runs, 849 assertions, no failures, errors or skips. These exercise the separate Auth ceremony entry helper whose stale Visitor reference was removed earlier.
- `bin/rails test` started 17,024 tests using 16 processes and was still running when this record was written; no final suite result is claimed here.
- Rails test database preparation was used; no production persistence operation or external write was performed.
