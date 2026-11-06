# App social callback guard tests

- Git HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had 372 unstaged tracked file changes and 76 untracked files before this evidence
  file was added; no staged changes. The test result was produced with this existing worktree.
- Updated the App social callback guard tests to use the Auth admission route, the configured Google
  provider mock keys, and the callback route's GET-only contract.
- `bin/rails test test/integration/social_callback_guard_test.rb`: 12 runs, 93 assertions, 0
  failures, 0 errors, 0 skips. The repository's local container environment file was loaded for the
  command; no values are recorded here.
- `bundle exec rubocop test/integration/social_callback_guard_test.rb`: 1 file inspected, no
  offenses.
- `ruby -c test/integration/social_callback_guard_test.rb` and `git diff --check` for the edited
  test files passed.
