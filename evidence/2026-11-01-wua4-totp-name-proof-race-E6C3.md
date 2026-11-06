# WU-A4 App TOTP rename concurrent Step-Up use

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had extensive pre-existing uncommitted changes, including this test and the related
  XDB-04 implementation. No commit was made; unrelated changes were preserved.
- Added a nontransactional concurrency case with two independent Active Record connections. A
  separate PostgreSQL connection held the Zenith Client row lock until both requests were waiting,
  then released it.
- Exactly one request changed the TOTP title; the other was denied after the one-time Step-Up was
  consumed. The final title matched the successful request and the evidence was spent.
- Ran
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/concurrency/identity_totp_name_commit_order_test.rb:92`:
  1 run, 5 assertions, 0 failures, 0 errors, 0 skips.
- Re-ran the complete `test/concurrency/identity_totp_name_commit_order_test.rb` file: 4 runs, 15
  assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop test/concurrency/identity_totp_name_commit_order_test.rb` reported no offenses. Ruby
  syntax and scoped `git diff --check` passed.
- This verifies duplicate-proof serialization only. The same-Zenith audit remains unimplemented
  pending owner approval of its persisted shape. No full suite was run; no Production or Neon
  database was accessed.
