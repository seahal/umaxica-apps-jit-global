# WU-A4 XDB-01 passkey registration rejects outer OP savepoints

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 519 status entries, including
this change; no staged changes were present. No commit was made.

Changed the existing outer-OP regression case to use `joinable: false`. Before changing the
committer, the case failed because `TransactionConflict` was not raised; teardown also observed a
stale `ClientStepUpCeremonyTransaction` after the unintended commit path. The final committer now
refuses whenever an OP transaction is already open, before reading the result reference.

Ran with `.env.container.devcontainer` loaded:

- Before the committer change, the focused case failed: 1 run, 1 assertion, 1 failure. The expected
  `TransactionConflict` was not raised.
- After the change,
  `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_passkey_registration_commit_order_test.rb`
  passed: 7 runs, 46 assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c` passed for the committer and test file; scoped `git diff --check` passed.
- RuboCop reported seven existing offenses in the test file at lines 55, 70, 88, 92, 239, 243 and
  252; none is in the changed test hunk. The committer had no offense.

This closes the demonstrated non-joinable outer-OP transaction gap for XDB-01. It does not establish
all other XDB-01 commit and recovery boundaries.
