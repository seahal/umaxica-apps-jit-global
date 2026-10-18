# Secret storage declaration and atomic activation

Performed 2026-10-04, recorded after 04:43 UTC (Etc/UTC).
Rails `feature`, HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The preceding capture had 387 dirty paths, including concurrent work.
Results include uncommitted changes and are not CI results.

ClientSecretStorageConfirmationCommitter implements the signed-in domain boundary
using existing issuance, credential and source-outbox columns. It rereads current
ownership and session facts, requires scoped session-bound Step-Up, checks the
issuance deadline, and compares the complete candidate ID set with per-candidate
presentation evidence. Signup issuance is refused by this operation. Manual
confirmation uses settings_secret_credential; prepared Passkey-origin batches
use settings_passkey. This test boundary does not establish registration-origin
authorization or plaintext delivery; the registration coordinator still needs
to bind actual registration and issuance to one authorized operation.

Client, Ticket Token, issuance and ordered candidate locks preserve the existing
lock order. Source declaration, all candidate activations and source events commit
together on Zenith. Ticket locks protect session reads without claiming a
distributed commit. Confirmation does not modify the Token or extend Step-Up.
Replay returns the same confirmed facts without additional events.

secret.storage_declared records the batch's user assertion. secret.created records
each credential's confirmed creation, rather than authentication or proof that
the user actually saved it. No raw value, digest or name is added to source events.

## Execution

Used only the guarded codex_integrity_20261004registration_* disposable fleet
through `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test <paths>`.

- Red: new confirmation test, 1 test/0 assertions/1 error because the operation
  was absent. Environment preparation succeeded. The subsequent partial operation
  run reached the missing model transition before its implementation.
- Initial Green: confirmation and rebuilt credential suites, 8 tests/45 assertions,
  zero failures/errors/skips.
- Two-candidate activation and actual source event validation failure verified
  all-or-none rollback: 2 tests/25 assertions, zero failures/errors/skips.
- Expanded authorization/presentation cases: 6 tests/109 assertions, zero failures,
  errors or skips. Cases include missing/expired Step-Up, wrong owner/scope/session,
  revoked/restricted sessions, Secret as proof method, missing/incorrect presentation
  audit and extra candidates. Issuance expiry uses one microsecond before/equal/after
  the deadline. The public writer-time accessor is controlled; this does not claim
  that PostgreSQL's clock was advanced.
- Separate writer connections with PostgreSQL backend IDs, Queue barriers,
  Concurrent::Future and bounded waits verified duplicate confirmation converges
  to one declaration/activation. No sleep-only sequencing or new Thread site.
- Final related regression selected both confirmation files, manual reservation
  and its concurrency tests, cancellation/expiry, name/revocation, credential,
  issuance/outbox, lookup/capacity, ownership/AuthMethodGuard and inventory suites:
  **110 tests, 1,207 assertions, zero failures/errors/skips**.
- Final plain `bundle exec rubocop` on operation, model and two confirmation tests:
  four files, no offenses. Formatting corrections and method extraction preserved
  the existing gates.
- `git diff --check`: PASS.

## Model protection and review adjustment

The final transition uses ordinary validated save with an instance-scoped write
interval that closes through ensure on every outcome. Ordinary writer assignment,
raw attribute assignment, update_columns and touch reject confirmed_at changes;
terminal timestamps cannot be cleared or replaced at adjacent microsecond values.
The installed Rails readonly writer and persistence hooks were inspected at
Rails 2f75a03b05aff2610b3799ef9ebd87cfc9cf38eb, in readonly_attributes.rb and
persistence.rb. Other readonly columns retain Rails' ordinary implementation.

An intermediate conditional update_all implementation passed behavior checks but
violated the no-validation-skipping lint gate. It was replaced, not suppressed.
The final code has no validation-skipping update or framework-wide setting change.
No migration, payload codec, Chronicle wire shape or production duration was added.

NOT_RUN: management HTTP/UI, initial signup confirmation, actual Passkey registration
binding, protected plaintext delivery/browser secrecy, confirmation versus claim
or cancellation races, full suite, Chronicle delivery and audited purge. Prepared
Step-Up/presentation evidence is not a completed authentication/browser journey.
The goal remains incomplete; this record proves the signed-in confirmation slice.
