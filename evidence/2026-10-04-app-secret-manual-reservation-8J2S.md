# app Secret manual capacity reservation

Executed on 2026-10-04 UTC; final observation at 01:58 UTC against Rails feature
HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The worktree had 279 dirty
paths before this record, including concurrent agent work. Used only the guarded
`codex_integrity_20261003secret_*` disposable database fleet.

Added ClientSecretManualReservationIssuer, a public management operation that
reserves one item without generating credentials, plaintext or an encrypted
payload. It rereads the Client and current owning session, requires existing
scoped Step-Up, and serializes capacity under the Client writer lock. Reservation
and source audit commit together on Zenith; Ticket is read/locked only. No schema,
serialized format, production expiry default or HTTP entry was added.

The server caller supplies the operation UUID and explicit duration. UUID syntax
is input validation, not proof of authority. Authorized retry returns the same
bound allocation without extending expiry; another Client/session cannot retrieve
it. Expired allocation remains expired, while a new operation can reserve freed
capacity without jobs. A live different operation conflicts even with headroom.
Manual addition at twenty active items raises CapacityFull without creating an
omission allocation. Zero/one balances trigger no automatic issuance here.

Verification:

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/operations/client_secret_manual_reservation_issuer_test.rb`: initial
  Red, two errors because the operation was absent; database setup succeeded.
  Initial two-case Green: two tests, 32 assertions. The expanded authorization
  run initially had one invalid expired-Token fixture; corrected its timestamp
  while retaining the expiry rejection expectation.
- Expanded reservation/capacity/issuance selection: 20 tests, 251 assertions,
  no failures/errors/skips. Covers active counts 0/1/18/19/20, exact retry,
  other-operation conflict, wrong owner/session, scoped Step-Up rejection,
  expired allocation, UUID/type sentinels, negative/zero/one-microsecond duration
  and actual outbox validation failure rolling the allocation back.
- Separate-writer concurrency test uses two distinct session rows and PostgreSQL
  backend IDs, Queue barriers and the existing Concurrent::Future implementation.
  No sleep-only sequencing or new lint suppression. At A=18 and A=19 exactly
  one reservation wins; at A=20 both are refused. Postconditions verify A/R,
  the twenty-item bound and one/no source event as applicable.
- Concurrency setup initially timed out because the main/future execution contexts
  retained the two configured connections. Released setup leases and used fixed
  Rails with_connection(prevent_permanent_checkout: true) for both writer pools.
  The actual source in the installed Rails commit confirms that API restores the
  prior sticky lease and releases the checkout. No pool size or environment
  requirement was changed. Corrected cached-parent cleanup with reload.
  These failed setup attempts are not product Red. The successful concurrency
  plus reservation/capacity/issuance selection ran 21 tests, 272 assertions.
- Final wrapper selection included both reservation files, retirement/name
  operations, outbox/credential/issuance models, issuance-count value,
  capacity/lookup queries, ownership/AuthMethodGuard policies and both inventory
  suites: **95 tests, 881 assertions, no failures/errors/skips**.
- `bundle exec rubocop app/operations/client_secret_manual_reservation_issuer.rb
  test/operations/client_secret_manual_reservation_issuer_test.rb
  test/operations/client_secret_manual_reservation_concurrency_test.rb`: PASS,
  three files and no offenses after formatting. No gate changes.
- `git diff --check`: PASS before this record.

HTTP admission/rate limiting, candidate creation, encrypted delivery, confirmation,
Passkey 2/1/0 registration integration, claim/login, Chronicle delivery and audited
purge remain incomplete. These tests prepare stored Step-Up facts; no real
ceremony, browser, full suite, Passkey/manual competition or confirmation race is
claimed. Pending serialized/claim/Chronicle shape approvals remain separate.
No shared database, real credential, external send, push or deployment was used.
