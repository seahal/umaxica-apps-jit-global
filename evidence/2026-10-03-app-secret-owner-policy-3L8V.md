# app Secret ownership policy cutover

Executed on 2026-10-03 (UTC), against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted changes.

ClientSecretCredentialPolicy still used the old user_id and inherited the generic
owner predicate, which did not recognize new client_id ownership. Replaced its
record rules and relation scope with explicit ClientSecretCredential/client_id
checks. List/create require a persisted Client. Record access requires a persisted
credential owned by that Client. Removed the obsolete regenerate permission; this
policy provides no reactivation or secret-value replacement operation.

Step-Up, scope, freshness and current session checks remain separate required gates
on mutating callers. Passing this ownership policy does not authorize issuance,
presentation, confirmation, rename or deletion without those gates. No management
controller, route or mutation operation was connected in this slice.

## Actual execution

Tests ran through `bundle exec ruby /tmp/umaxica-secret-db-task.rb test ...`, using
only the task-owned disposable `codex_integrity_20261003secret_*` fleet.

- Red: 6 tests, 32 assertions, 2 failures and 1 error. Owner access was denied,
  scope queried the removed user_id column, and an unsaved Client was accepted.
- Green: 6 tests, 49 assertions, no failures/errors/skips. Tests use Action Policy's
  public apply API, including its pre-checks, and public relation scoping. Covers
  anonymous actors, owner and other Client, foreign actor types with colliding IDs,
  unsaved actors/records, aliases for new/edit and actual scoped database rows.
- Combined new policy, existing Visitor/Operator policies and six Secret foundation
  test files: **62 tests, 305 assertions, no failures/errors/skips**. This is limited
  com/org policy regression, not their complete Recovery/Emergency journeys.
- RuboCop on the policy passed. Two test assertion-spacing offenses were corrected
  with `bundle exec rubocop -a test/policies/client_secret_credential_policy_test.rb`;
  no outstanding offense remained. `git diff --check` passed.

The existing app Step-Up scope still refers to legacy settings paths; connecting
the canonical Base secrets resource needs that existing scope's return-path contract
aligned with the new routes. No AAL threshold or bootstrap bypass was added.
Chronicle delivery metadata is separately proposed, not implemented or verified.
