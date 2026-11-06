# WU-A4 App Secret rename concurrent Step-Up use

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had extensive pre-existing uncommitted changes, including this test and the related
  XDB-05 implementation. No commit was made; unrelated changes were preserved.
- Added a concurrent operation case using two request threads with independent Active Record
  connections. A separate PostgreSQL connection held the Zenith Client row lock until both requests
  were waiting, then released it.
- Exactly one request renamed the Secret and wrote one `secret.renamed` source audit event; the
  other request was denied after the one-time Step-Up was consumed. The final name was one of the
  submitted names and the token evidence was spent.
- Ran
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_name_committer_test.rb:382`:
  1 run, 6 assertions, 0 failures, 0 errors, 0 skips.
- Re-ran the complete `test/operations/client_secret_name_committer_test.rb` file: 17 runs, 171
  assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop test/operations/client_secret_name_committer_test.rb` reported no offenses. Ruby
  syntax and scoped `git diff --check` passed.
- This verifies the same-proof race direction only. Other XDB-05 acceptance boundaries remain open.
  No full suite was run; no Production or Neon database was accessed.
