# Auth Ceremony Database Clock Check

## Scope

This checkpoint covers the `AuthCeremonySession` lifecycle timestamp change. New records and
terminal transitions use the writer database clock unless an explicit decision time is supplied;
the lifecycle test also verifies that the same decision time is used for creation, admission, and
completion.

## Static verification

Executed from the current worktree:

```text
ruby -c app/models/concerns/auth_ceremony_session.rb
ruby -c test/models/auth_ceremony_session_test.rb
bundle exec rubocop app/models/concerns/auth_ceremony_session.rb test/models/auth_ceremony_session_test.rb
git diff --check
```

Result: syntax checks passed, RuboCop reported no offenses for both files, and `git diff --check`
passed.

## Rails verification

The required environment file and test database list were exported before running:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/auth_ceremony_session_test.rb
```

The test process did not reach Minitest. Rails schema maintenance failed while connecting to the
configured PostgreSQL host because the current process cannot resolve `primary`:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Runs, assertions, failures, and skips are therefore unreported: zero tests were executed. This is
an environment/network blocker, not a passing or failing result for the changed behavior. No
application code, test, or configuration was changed to bypass it, and no PostgreSQL, Valkey, AWS,
or Cloudflare service was modified.
