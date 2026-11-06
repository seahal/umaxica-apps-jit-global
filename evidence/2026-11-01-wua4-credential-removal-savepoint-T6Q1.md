# WU-A4 XDB-07 credential removal rejects outer OP savepoints

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 518 status entries, including
this change; no staged changes were present. No commit was made.

Added a public-call regression case using a non-joinable outer OP transaction. Before the
implementation change, that case failed because `TransactionConflict` was not raised. The
credential-removal writer now refuses whenever an OP transaction is already open.

Ran with `.env.container.devcontainer` loaded:

- Before the implementation change,
  `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_credential_removal_committer_test.rb:62`
  failed as expected: 1 run, 1 assertion, 1 failure
  (`TransactionConflict expected but nothing was raised`).
- After the change,
  `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_credential_removal_committer_test.rb`
  passed: 16 runs, 173 assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c` passed for the operation and test file.
- RuboCop inspected both files with no offenses.
- Scoped `git diff --check` passed.

This closes the demonstrated non-joinable outer-OP transaction gap. It does not establish the
remaining XDB-07 commit-failure, authorization, or cross-database audit boundaries.
