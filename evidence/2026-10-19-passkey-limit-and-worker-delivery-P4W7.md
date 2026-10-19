# Passkey limit without slots, and real-worker audit delivery

Date: 2026-10-19. Commit: `ff58ff28125fafe405dc76809f6498b64d69e627`, with the uncommitted three.md
cycle and the Rails-standard credentials change
(`evidence/2026-10-19-rails-standard-credentials-and-fixed-dev-db-C7R2.md`) in the worktree.

## Slot migration failure that led to the change

Running the cycle migrations against the populated isolated fleet `codex_integrity_20261017c1a2_*`
failed with
`PG::NotNullViolation: column "registration_slot" of relation "operator_passkeys" contains null values`.
The slot migrations added a NOT NULL column without numbering existing rows and used
`column_exists?`/`if_not_exists` skip guards. Fresh, empty development and test databases had hidden
the failure.

User decision (2026-10-19): drop the slot schema and enforce the ten-Passkey limit with an
owner-locked count check. Recorded in `adr/passkey-current-state-limit-and-chronicle-outbox.md`,
six.md and `plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`.

## Checks after the change

- Development and test databases dropped and rebuilt. `db:migrate:status`: no `down` and no
  `NO FILE` versions. The three `20261019120004_add_unique_external_id_index_to_*_passkeys`
  migrations were rolled back and reapplied on APP, COM and ORG; ORG ends with only
  `index_operator_passkeys_on_external_id_unique`.
- `db:schema:dump` on PostgreSQL 18.6 also re-deparsed unrelated `CHECK ... = ANY (ARRAY[...])`
  constraints in nine dumps. Only the intended changes were kept: outbox tables, withdrawal deadline
  columns, `external_id` unique indexes. No dump contains `registration_slot`.
- Every test file that referenced slots, plus the new operation, concurrency and invariant tests:
  994 runs, 10696 assertions, 0 failures, 0 errors. This includes the 9/10/11 boundary on APP, COM
  and ORG, freed capacity after deletion, a per-owner partition, and two threads on independent
  connections racing for the tenth place (exactly one committed, total 10).
- The isolated fleet was rebuilt with `scripts/postgresql-rebuild-isolated-test-fleet` (32
  databases, 12 roles re-receipted). With `PARALLEL_WORKERS=2` on that fleet, the 14
  committed-transaction Avatar tests that the ordinary suite reports as
  `committed tests require run-owned worker receipts` passed: 74 runs, 300 assertions, 0 failures, 0
  errors.
- RuboCop on the 109 changed files: no offenses.

## Real Solid Queue worker execution (U13, development)

- A Client Passkey was registered through `PasskeyRegistrationOperation` with an audit outbox row
  (`event_uuid` `3217214e-c346-4a67-9124-ca52a386dca1`), and `PasskeyAuditDeliveryJob` was enqueued
  twice.
- `bin/jobs` for 40 s: both jobs failed with `ActiveRecord::RecordNotFound` for
  `ChronicleRetentionPolicy` code `security`. The development database had no security policy, which
  is provisioned only by `app_secret:provision_audit_policy` with an approved duration. Delivery
  failed closed; the outbox row stayed unacknowledged.
- The policy was provisioned with `CHRONICLE_SECURITY_RETENTION_DAYS=365`. This is a
  development-only value, not a decision on Passkey Chronicle retention, which is still TBC. Both
  failed executions were retried with `SolidQueue::FailedExecution#retry`, then `bin/jobs` ran for
  30 s.
- Result: both jobs finished, 0 failed executions, exactly one Chronicle row for the event
  (`passkey.registered.settings`, `occurred_at` equal to the source), metadata keys `actor_ref`,
  `external_id`, `surface`, and the outbox acknowledged.
- `RetentionPurgeJob.perform_later` and then `bin/jobs` for 45 s: finished, no failed execution.

## Not performed

- A Chronicle database outage during delivery was not simulated.
- Production worker execution was not observed; this shell has no production environment.
- Any deployed environment needs the `security` Chronicle policy provisioned with an approved
  duration before Passkey audit delivery can succeed.
