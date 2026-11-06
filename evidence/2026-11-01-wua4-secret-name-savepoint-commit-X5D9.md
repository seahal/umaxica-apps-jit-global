# WU-A4 XDB-05 Secret rename rejects outer OP savepoints

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 516 status entries, including the
changes recorded here; no staged changes were present. No commit was made.

Changed the Secret rename commit guard to refuse whenever an OP transaction is open. Before the
change, a regression case using `transaction(joinable: false)` failed because no
`TransactionConflict` was raised. The operation test now runs without transactional fixture wrapping
and restores the fixture Client's tokens, devices, Secret rows and newly written audit rows after
each case. The HTTP success path also has a separate nontransactional integration test; the existing
fixture-wrapped case now tests the dependency-failure response only.

Ran with `.env.container.devcontainer` loaded:

- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_name_committer_test.rb`: 15 runs,
  161 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_concurrency_test.rb -i '/source audit failures/'`:
  1 run, 14 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/client_secret_name_committed_http_test.rb`: 1
  run, 4 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/step_up_authentication_test.rb -i '/Secret rename maps storage dependency failures/'`:
  1 run, 4 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the operation, its operation test and the new HTTP test: 3 files, no offenses. RuboCop
  on the pre-existing large Step-Up integration file reports two unrelated whitespace offenses at
  lines 1213–1214; neither is in the changed hunk.
- `ruby -c` on all four changed Ruby files: syntax OK. Scoped `git diff --check`: passed.

This closes the demonstrated outer-OP savepoint gap for XDB-05. It does not close the other XDB-05
failure boundaries or XDB-03's same-Zenith audit requirement.
