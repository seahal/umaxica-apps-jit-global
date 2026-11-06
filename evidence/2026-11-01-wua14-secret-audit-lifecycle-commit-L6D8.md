# WU-A14 BL-19 Secret audit lifecycle test commit boundary

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained extensive uncommitted
  changes; no commit was made.
- The existing fixture-table narrowing in `test/jobs/client_secret_audit_delivery_job_test.rb` was
  preserved. The lifecycle test called `ClientSecretStorageConfirmationCommitter` inside Rails'
  outer fixture transaction, contrary to the operation's independent-OP-commit contract.
- Reproduced the issue with
  `bin/rails test test/jobs/client_secret_audit_delivery_job_test.rb --name '/real lifecycle delivery precedes credential deletion/'`:
  1 run, 0 assertions, 1 error, `ClientSecretStorageConfirmationCommitter::TransactionConflict`.
- Moved only that lifecycle case into a separate TestCase with transactional tests disabled and no
  fixtures. Teardown removes its actor, credentials, passkey, Secret outbox rows, corresponding
  Chronicle events, tokens, device sessions, authority lock and Preference row.
- The targeted lifecycle case passed: 1 run, 21 assertions, 0 failures, 0 errors, 0 skips.
- Full affected file passed: 10 runs, 100 assertions, 0 failures, 0 errors, 0 skips. Existing NanoID
  frozen-string warnings appeared.
- `bundle exec rubocop test/jobs/client_secret_audit_delivery_job_test.rb --format simple` passed
  with no offenses. `ruby -c` and `git diff --check` passed.
- This verifies the local Secret audit retention test path only. No full suite, production, Neon or
  external operation was run.
