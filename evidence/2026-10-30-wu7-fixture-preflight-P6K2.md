# WU-7 fixture preflight

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the preflight and its test-helper integration.
- A test-helper preflight checks for existing com browser-binding and web-push rows before Rails fixtures are loaded. It raises if either table is missing or either table contains rows.
- Executed `RAILS_ENV=test bin/rails runner 'require Rails.root.join("test/support/com_preference_fixture_preflight"); ComPreferenceFixturePreflight.verify!'`. It exited 1 as intended, reporting three browser bindings and three web pushes. This invocation did not load fixtures.
- `bundle exec rubocop test/support/com_preference_fixture_preflight.rb --format simple` passed. Ruby syntax checks passed for the preflight and test helper; `git diff --check -- test/test_helper.rb` passed.
- The empty-table path was not exercised. The full test suite was not run: fixture execution previously altered existing Chronicle records, and recovery remains unresolved. This preflight only guards the two specified com child tables after the Rails environment loads; it does not guarantee protection from earlier test database preparation, parallel database cloning, or changes to other tables.
