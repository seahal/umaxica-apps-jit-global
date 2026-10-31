# Historical A05-6 pending social Client

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this check.
- The current Google confirmation request test now checks the newly created Client is unfinished, cannot sign in, and has neither a linked social identity nor a token before finalization. The pending-Client termination test now also checks that sign-in is refused before and after cancel, expiry and halt; it already checks cleanup and no identity or token.
- `PARALLEL_WORKERS=1 bin/rails test test/services/social_pending_client_termination_test.rb test/integration/social_login_admission_test.rb test/services/social_auth_login_handler_test.rb -n '/A05-6|A29-6|L6.*unfinished_registration/'`: 3 runs, 78 assertions, 0 failures, 0 errors. RuboCop passed for the two edited files after formatting; scoped `git diff --check` passed before that formatting.
- Repeated confirmation, independent cleanup races, equivalent Apple-specific cleanup and the newer completion-receipt requirement remain unverified. The tests use stubs at the provider boundary; no production code changed in this slice.

## Apple-tagged pending Client follow-up

- The cancellation, expiry and halt test now repeats its checks for both Google- and Apple-tagged pending Clients. It passed: 1 run, 60 assertions, 0 failures, 0 errors. RuboCop and scoped `git diff --check` passed.
- This supersedes the earlier limitation on testing an Apple-tagged pending Client through termination. It does not exercise an Apple provider callback through cleanup, repeated confirmation, or independent cleanup races.
