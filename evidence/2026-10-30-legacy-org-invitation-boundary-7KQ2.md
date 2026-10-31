# Legacy organization invitation boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the test.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/sign_entry_invitation_parent_test.rb`.
- Result: 3 runs, 42 assertions, no failures, errors, or skips. Schema maintenance was disabled, so pending migrations were not applied.
- The tests exercise parent lookup before attachment and disabled-flow rejection on app and org surfaces. They also verify that a confirmed legacy org invitation cannot create a normal sign-in admission, change its binding, or issue a new session identifier.
- This does not establish complete organization invitation registration. The organization consolidation specification suspends legacy invitation acceptance pending review of ownership, target unit, and role mappings.
