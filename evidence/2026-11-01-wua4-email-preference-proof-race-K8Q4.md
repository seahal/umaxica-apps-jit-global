# WU-A4 App Email preference concurrent Step-Up use

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had extensive pre-existing uncommitted changes, including this test and the related
  XDB-03 implementation. No commit was made; unrelated changes were preserved.
- Added a nontransactional concurrency case with two request threads and independent Active Record
  connections. A separate PostgreSQL connection held the Zenith Client row lock until both requests
  were waiting on it, then released the lock.
- Exactly one request changed the Email preference and wrote one `preferences_changed` audit; the
  other was denied after the one-time Step-Up was consumed. The test also verified the persisted
  preference and spent evidence.
- Ran
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/concurrency/identity_email_preference_commit_order_test.rb`:
  3 runs, 14 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/operations/identity_email_preference_committer.rb test/concurrency/identity_email_preference_commit_order_test.rb`
  reported no offenses. Ruby syntax and scoped `git diff --check` passed.
- This verifies the same-proof race direction only. It does not establish completion of all
  XDB-03/WU-A4 acceptance. No full suite was run; no Production or Neon database was accessed.
