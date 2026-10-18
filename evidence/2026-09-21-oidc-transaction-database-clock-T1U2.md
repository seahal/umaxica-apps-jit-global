# OIDC authorization transaction database-clock state transitions

Date: 2026-09-21

## Scope

OIDC authorization transaction creation and the authenticated/consumed state transitions now use
one writer-database `clock_timestamp()` decision time per public operation unless an explicit test
clock is supplied. The decision time is selected before the creation write, or after the row lock
for an existing transaction, and the same value is used for expiry checks and lifecycle timestamps.
The caller-supplied authentication event time remains an external event fact and is not replaced by
the database clock.

The service test exercises issue, authentication-result registration, and consumption through the
public coordinator API and asserts the database-clock timestamps.

## Verification

Static checks passed:

- `ruby -c app/models/concerns/oidc_authorization_transactionable.rb`
- `ruby -c app/services/oidc_authorization_transaction_coordinator.rb`
- `ruby -c test/services/oidc_authorization_transaction_service_test.rb`
- `bundle exec rubocop app/models/concerns/oidc_authorization_transactionable.rb app/services/oidc_authorization_transaction_coordinator.rb test/services/oidc_authorization_transaction_service_test.rb`
- `git diff --check`

The focused Rails test could not boot in the current agent environment. Rails test-schema
maintenance failed before any test ran because PostgreSQL host `primary` could not be resolved:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

This slice is therefore unverified by Rails execution. No green test result is claimed. The
environment failure and the earlier historical suite result are recorded separately in
`evidence/2026-09-21-phase-00-preflight-R3S4.md`.
