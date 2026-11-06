# WU-A4 XDB-03 Email preference rejects outer OP savepoints

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 514 status entries, including the
changes recorded here; no staged changes were present. No commit was made.

Before the implementation change, a non-joinable outer OP transaction reproduced the defect:
`IdentityEmailPreferenceCommitter::TransactionConflict expected but nothing was raised`. The
preference could commit in Zenith while the outer OP rollback restored consumed Step-Up evidence.
The operation now refuses whenever an OP transaction is open; checking only `joinable?` missed this
savepoint boundary. The operation tests now run without transactional fixtures and explicitly remove
the actor, Email, token, device and related rows they create, so they exercise independent database
commits.

Ran with `.env.container.devcontainer` loaded:

- `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_email_preference_committer_test.rb test/concurrency/identity_email_preference_commit_order_test.rb`:
  10 runs, 59 assertions, 0 failures, 0 errors, 0 skips.
- Targeted RuboCop on the operation and both test files: 3 files inspected, no offenses.
- `ruby -c` on all three Ruby files: syntax OK.
- Scoped `git diff --check`: passed.

This closes the demonstrated non-joinable outer OP transaction gap for XDB-03. Same-Zenith audit
recording and the other XDB-03 boundaries remain open.
