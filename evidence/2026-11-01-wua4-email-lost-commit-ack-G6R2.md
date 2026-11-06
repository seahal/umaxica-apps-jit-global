# WU-A4 XDB-03 Email preference lost commit acknowledgement

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was already extensively dirty and had no staged changes. This test and its `four.md`
update are uncommitted.

Added an independent-commit APP test that disconnects the Zenith connection after PostgreSQL commits
an Email preference change and its Contact audit, then injects a lost acknowledgement. The caller
receives `IdentityEmailPreferenceCommitter::DependencyFailure`; fresh reads observe the changed
preference, consumed Step-Up and exactly one `preferences_changed` audit. After fresh Step-Up bound
to the same Email, retry returns the unchanged preference without consuming that proof or adding
another audit.

Verification:

- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/concurrency/identity_email_preference_commit_order_test.rb`:
  4 runs, 22 assertions, 0 failures, 0 errors, 0 skips.
- Focused added case: 1 run, 8 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/concurrency/identity_email_preference_commit_order_test.rb`: clean.
- `ruby -c test/concurrency/identity_email_preference_commit_order_test.rb`: syntax OK.
- `git diff --check -- test/concurrency/identity_email_preference_commit_order_test.rb`: clean.

The full suite was not run. This verifies the APP Email preference update acknowledgement-loss path;
Email registration, credential removal and broader suite closure remain outside this result.
