# Credential removal commit-order tests

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the application and tests.

With the configured local test environment, `PARALLEL_WORKERS=1 bin/rails test test/concurrency/identity_credential_removal_commit_order_test.rb` passed: 4 runs, 23 assertions, 0 failures, 0 errors and 0 skips.

These tests cover selected standalone cross-database failures; they do not cover or repair the previously reproduced outer Ticket transaction defect. A guard against an existing Ticket transaction would also encounter the transaction wrappers used by existing tests; its caller and test impact has not yet been resolved.
