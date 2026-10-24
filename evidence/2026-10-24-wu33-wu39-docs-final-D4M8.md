# WU-33 and WU-39: failure convergence and current documentation

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.

Observed with unrelated uncommitted changes preserved. This record covers documentation and research
reconciliation only; it is not a claim that the repository-wide acceptance inventory is green.

## Updated

- The sign-in failure convergence research now records the APP/COM/ORG method matrix and the
  remaining method-specific differences under the shared refusal catalogue.
- Current ADRs and checklists describe Visa as the OP, Base as the browser RP, the Design D
  continuation contract, the Sentry availability boundary, Auth-side social finalization and the
  dedicated RP logout hint storage.
- Historical/deferred Jump and Edge material remains separate and was not included in the scoped
  implementation.

## Verification

- `git diff --check`: passed during this implementation cycle.
- `bin/rails zeitwerk:check`: passed; Rails emitted the existing vendor `rails_db` eager-load
  warning and then reported “Otherwise, all is good!”.
- The changed Visa TypeScript entrypoints/styles passed direct `oxfmt --check`, `oxlint` and
  `tsc --build --pretty false`.
- Full `bin/rails test` was not green and is not represented as a completion result.
