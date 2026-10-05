# app Secret credential model rebuild

Executed on 2026-10-03, approximately 22:32–22:36 UTC, on feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted changes.

Replaced ClientSecretCredential's old kind/status/counter and recovery-validator
implementation with the approved Zenith-owned credential shape. Ownership is
`client_id`, with a required issuance association. Client's matching association
now uses that key and restricts destructive owner deletion instead of cascading
through credential destruction. Identity, ownership, digest, and terminal-fact
columns are readonly for ordinary model updates; name remains editable.

Availability depends on confirmed, unclaimed, unrevoked, undiscarded facts, independently
of account login authorization. Both the relation and instance interface use that
predicate. Whole-secret verification first validates exact 32-character Base58,
uses the existing SignSecretLookupDigest HMAC, and performs full password verification
through the existing Rails Argon2 algorithm. Nothing normalizes or truncates input.
Verification alone does not establish availability, claim, or a session.

## Executed checks

Tests ran only on the task-owned disposable `codex_integrity_20261003secret_*`
fleet through `bundle exec ruby /tmp/umaxica-secret-db-task.rb test ...`.

- Red for `test/models/client_secret_credential_rebuild_test.rb`: four errors for
  missing new public methods, after test environment preparation succeeded.
- The first replacement run stopped during eager loading because the old shared
  final committer referenced the removed app MAX_SECRETS_PER_USER constant. Removed
  its obsolete app configuration instead of adding a compatibility alias. Its
  com/org configurations remain in source. The committer now rejects unsupported
  surfaces before accessing ceremony evidence.
- Green for the four public domain tests: 4 tests, 21 assertions, no failures,
  errors, or skips.
- Added a real persistence test: an unconfirmed candidate was saved with a Client
  and issuance, without recovery identity requirements; it remains unavailable,
  exact matching works after reload, Client association resolves correctly, and
  attempted secret replacement raises ReadonlyAttributeError. Five credential
  tests passed with 27 assertions and no failures/errors/skips.
- Combined credential, outbox, issuance-state, and count tests: **27 tests,
  162 assertions, no failures, errors, or skips**.
- RuboCop on the replaced model and new credential test passed after formatting.
  `git diff --check` passed.

Format partitions include 31/32/33 characters, empty, nil, numeric zero, arrays,
hashes, NUL, forbidden alphabet, wrong value, case change, and mismatching lookup
digest. Logical discard is tested immediately before, at, and after the deadline.

## Remaining integration

The new model is not yet a working Secret product. Shared Recovery top-up app
callers, old app fixtures/seeds/kind/status classes, Emergency route and operation,
issuance/reservation operations, explicit delivery and confirmation, scoped management,
normal Secret Sign in, canonical receipt writing, outbox delivery, and purge delegation
still require replacement. Ordinary shared database application and deployment remain
unauthorized. com/org runtime regression was not run in this slice; preserved source
configuration is not reported as proof of behavioral equivalence.
