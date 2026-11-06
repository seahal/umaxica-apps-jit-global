# WU-A4 XDB-06 Secret confirmation rejects outer OP savepoints

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 517 status entries, including the
changes recorded here; no staged changes were present. No commit was made.

Changed the signed-in Secret confirmation guard to refuse whenever an OP transaction is open. A
`joinable: false` outer OP transaction reproduced the gap before the change: the expected
`TransactionConflict` was not raised. The operation test class now runs without fixture transactions
and deletes only the Client, token, device, issuance, candidate, preference and audit rows it
creates. The sign-up confirmation path remains on its separate transaction contract and does not use
this guard.

Ran with `.env.container.devcontainer` loaded:

- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_committer_test.rb`:
  9 runs, 157 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_concurrency_test.rb`:
  5 runs, 56 assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c` on the operation and test file: syntax OK.
- Scoped `git diff --check`: passed.
- RuboCop reported one pre-existing `Layout/EmptyLineAfterGuardClause` offense in the operation at
  line 22, outside the changed hunk.

This closes the demonstrated outer-OP savepoint gap for signed-in XDB-06. It does not close the
remaining XDB-06 cross-database failure boundaries.
