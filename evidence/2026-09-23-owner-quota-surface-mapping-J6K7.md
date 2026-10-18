# Owner quota surface mapping

- Date: 2026-09-23
- Repository commit: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: uncommitted changes were present and preserved.

Added public policy-contract coverage for the four previously untested non-app owner mappings:

- `Visitor -> Individual` account quota;
- `Operator -> Agent` account quota;
- `Visitor -> Company` organization quota;
- `Operator -> Bureau` organization quota.

Each test creates the concrete principal, surface-local resource, explicit active lifecycle row,
and explicit ownership row, then verifies the policy count and remaining quota. Existing app
coverage continues to exercise the lifecycle boundary and fail-closed behavior. The test file is
syntax-valid and RuboCop-clean.

The Rails test could not reach assertions in the current process because `getent hosts primary`
and `getent hosts valkey-kvs` returned no records and the configured PostgreSQL host failed with
`PG::ConnectionBad`. No service, application configuration, or test fallback was changed.
