# Core APP RP-cell readiness baseline

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including RP authentication and logout code; this result applies to that worktree.

An initial line-number selection of `test/integration/rp_cell_local_session_readiness_test.rb:24` selected no tests (0 runs). Repeating with `PARALLEL_WORKERS=1 bin/rails test test/integration/rp_cell_local_session_readiness_test.rb -n '/core-app-jp/'` passed: 1 run, 3 assertions. The case verifies local RP-cell authentication and refusal without a local session or after local OP binding revocation. It does not exercise sign-out or a database outage.

The reviewed source shows that RP-cell sign-out credential resolution catches an Active Record error and maps it to missing credentials, while launch maps a database error to the existing unavailable response. A real request with an injected failure has not yet been run, and response changes have not been implemented.
