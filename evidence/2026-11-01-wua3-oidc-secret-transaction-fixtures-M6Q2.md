# WU-A3 OIDC Secret transaction fixture isolation

- Ran `RAILS_ENV=test bin/rails test test/integration/oidc_initiated_sign_in_completion_test.rb`
  with `.env.container.devcontainer` loaded: 16 runs, 272 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/integration/oidc_initiated_sign_in_completion_test.rb` and
  `git diff --check` passed.
- The Secret claim cases use a test-owned Client outside Rails' fixture transaction and remove their
  contacts, OIDC rows, retention holds, tokens, stops, and audit records in teardown. A post-run
  query found no synthetic Client, hold, connection, or matching test contact left in the local test
  database.
- During earlier attempts, exact test-created Client `980190963`, retention hold `6`, and OP
  connection `1296` survived teardown. They were identified by public ID and creation time, then
  removed. Cleanup was extended before the passing run.
- No full suite was run. This verifies only this OIDC integration file; WU-A3's wider acceptance
  remains open.
- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had uncommitted changes, including
  the test changes recorded here.
