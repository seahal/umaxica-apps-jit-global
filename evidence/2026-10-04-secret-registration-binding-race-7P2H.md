# Registration provenance diagnosis and confirmation/cancellation race

Performed 2026-10-04, recorded at 05:02 UTC (Etc/UTC).
Rails `feature`, HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The preceding capture had 394 dirty paths, including concurrent work.
Results are local and include uncommitted changes, not CI results.

## Registration binding gate

Current settings registration calls SignSettingsPasskeyRegistration. Its ceremony
start returns nil and its finish saves ClientPasskey directly after the shared
WebAuthn verifier. It does not invoke IdentityPasskeyCeremonyFinalCommitter.
Therefore the old Ticket passkey ceremony table cannot be assumed to prove this
registration or its authorized Secret issuance.

Read-only runner `/tmp/umaxica-secret-registration-ownership.rb`, executed through
the guarded registration-fresh wrapper, confirmed Client, ClientPasskey, issuance
and credential on codex_integrity_20261004registration_app_zenith. The old passkey
ceremony transaction is on that fleet's app_ticket. Actual issuance columns have
no registered_passkey_ref. No secret or credential value was printed.

Added a concrete Before/After provenance snapshot proposal to
plans/analysis/app-secret-persistence-shape-proposal.md. It is not approved or
implemented. This is a registration-origin fact rather than Step-Up proof or a
reason to revoke already-confirmed Secrets when their originating Passkey is
removed. Actual registration/issuance authorization, retry and response-loss
integration still require implementation and public-path tests.

## Independent concurrency verification

Added a real two-writer confirmation-versus-cancellation test, using distinct
PostgreSQL backend IDs, Queue barriers, Concurrent::Future and bounded waits.
The test verifies one terminal result, one refused losing mutation, released R,
matching credential eligibility and corresponding source events. It checks either
permitted winner without asserting that both scheduler outcomes occurred in this
run. No sleep-only ordering, new Thread site or success mock was used.

- `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test` with confirmation
  concurrency, confirmation committer and manual cancellation files:
  **15 tests, 270 assertions, zero failures/errors/skips**.
- Plain `bundle exec rubocop test/operations/client_secret_storage_confirmation_concurrency_test.rb`:
  one file, no offenses after ternary formatting correction.
- `git diff --check`: PASS before this record.

Only the task-owned disposable fleet was used. No migration, new payload format,
Chronicle projection, deployment or shared DB operation was performed. The shape
question was registered; tool acknowledgement is not user approval.

NOT_RUN: full suite, cancellation versus two-item confirmation, claim/expiry races,
real registration delivery, signup completion, Secret login, Chronicle/purge or
browser secrecy. The confirmation slice remains unconnected to HTTP/UI.
