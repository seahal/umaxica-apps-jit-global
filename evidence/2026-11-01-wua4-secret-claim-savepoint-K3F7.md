# WU-A4 XDB-18 Secret claim rejects outer Zenith savepoints

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 520 status entries, including
this change; no staged changes were present. No commit was made.

The existing joined and nested-savepoint cases passed (2 runs, 10 assertions). Added a separate
non-joinable outer Zenith transaction case. Before changing the committer, it failed because
`TransactionConflict` was not raised. The writer now refuses whenever a Zenith transaction is
already open, before looking up or consuming the Secret.

Ran with `.env.container.devcontainer` loaded:

- Before the committer change, the focused case failed: 1 run, 1 assertion, 1 failure.
- After the change,
  `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_claim_concurrency_test.rb`
  passed: 9 runs, 76 assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c` passed for the committer and test file; RuboCop inspected both files with no offenses;
  scoped `git diff --check` passed.

This closes the demonstrated non-joinable outer-Zenith transaction gap for XDB-18. It does not
establish all XDB-18 claim, flow-finalization, or failure-recovery boundaries.
