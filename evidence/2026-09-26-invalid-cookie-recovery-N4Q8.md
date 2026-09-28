# Invalid Cookie Recovery Verification

Commit: `e423890e7357e1fa7975eac45aeacdb416b3bce9`. The worktree had extensive pre-existing uncommitted changes, including preference recovery code and tests, and additional uncommitted changes from this task.

- `ruby -c` passed for the modified auth, preference, and Core browser API concerns and the affected integration test files.
- `git diff --check` passed for the modified tracked code and test files.
- `bin/rails test test/integration/preference_corrupt_cookie_test.rb` did not run tests: PostgreSQL hostname `primary` could not be resolved or connected.
- `bin/rails test test/integration/auth_invalid_cookie_recovery_test.rb test/integration/preference_corrupt_cookie_test.rb test/integration/preference_entry_recovery_test.rb test/integration/preference_security_test.rb` stopped at the same database connection failure before tests ran.
- `bin/rails test` stopped at the same database connection failure before tests ran.

Neither `podman` nor `docker` is installed in this execution environment; the database stack could not be started through the repository's normal container setup here.
