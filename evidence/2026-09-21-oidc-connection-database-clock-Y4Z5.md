# OIDC Connection and RP Issuance Clock Check

## Scope

The OIDC authorization-code exchange now obtains one writer-database decision time after the
Base-session re-lock and passes it through connection recording, RP usage creation, refresh-token
issuance/rotation, and Access JWT maximum-expiry recording. The RP-session expiry calculation no
longer derives a refresh expiry from the Ruby process clock in this path.

## Static verification

Executed:

```text
ruby -c app/operations/oidc_connection_recorder.rb
ruby -c app/services/oidc_token_exchange_coordinator.rb
ruby -c app/models/concerns/rp_session.rb
ruby -c test/operations/oidc_connection_recorder_test.rb
ruby -c test/services/oidc/token_exchange_service_test.rb
bundle exec rubocop app/operations/oidc_connection_recorder.rb app/services/oidc_token_exchange_coordinator.rb app/models/concerns/rp_session.rb test/operations/oidc_connection_recorder_test.rb test/services/oidc/token_exchange_service_test.rb
git diff --check
```

Result: all syntax checks passed, RuboCop reported no offenses for the five files, and
`git diff --check` passed.

## Rails verification

The focused command was run after loading `.env.devcontainer.example` and setting the approved
test database list:

```text
PARALLEL_WORKERS=1 bin/rails test test/operations/oidc_connection_recorder_test.rb test/services/oidc/token_exchange_service_test.rb
```

Rails did not reach Minitest. Test-schema maintenance failed because the configured PostgreSQL
host `primary` could not be resolved:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Runs, assertions, failures, and skips are therefore unavailable; zero tests executed. No
application, test, or configuration workaround was added, and no external service was accessed or
modified.
