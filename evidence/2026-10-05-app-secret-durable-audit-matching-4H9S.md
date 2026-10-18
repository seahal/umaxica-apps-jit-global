# Durable audit matching before physical collection

Observed 2026-10-05 UTC, through 15:02:35+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted implementation,
test and documentation changes. Commands used the OID/owner-guarded disposable
`codex_integrity_20261005recovery_*` fleet on PostgreSQL 17.7.

`ClientSecretCredentialPurger.call!` and
`ClientSecretAuditOutboxPurger.call!` now require the actual Chronicle row to
match the immutable Source fact, including target metadata, operation, action,
time, result, reason, actor, Client subject and empty changeset. Matching UUID
and success alone cannot authorize physical deletion. Issuance collection
already checks these fields. No database shape or delivery payload changed.

Tests use real delivery and modify the durable record's target metadata while
retaining UUID and success. Collection must refuse deletion, then succeed when
the original metadata is restored. Corruption arrangement is confined to the
test database; no test-only production branch or authorization bypass was added.

Commands and observations:

- `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test
  test/operations/client_secret_audit_outbox_purger_test.rb
  test/jobs/client_secret_audit_outbox_purge_job_test.rb`: seed 17178,
  **8 runs, 45 assertions, no failures/errors/skips**, 7.150244 seconds.
  Earlier process handles 4025 and 88747 were missing; their lost final output
  was not treated as a successful result.
- Red: the same guarded runner with
  `test/jobs/client_secret_audit_delivery_job_test.rb
  --include '/expired unconfirmed candidates/'`: seed 61262,
  1 run, 4 assertions, 1 failure. Expected undelivered, received purged despite
  conflicting durable target metadata.
- Green: guarded runner with `test/jobs/client_secret_audit_delivery_job_test.rb`,
  `test/operations/client_secret_completed_issuance_purger_test.rb` and
  `test/jobs/client_secret_lifecycle_job_test.rb`: seed 24501,
  **22 runs, 324 assertions, no failures/errors/skips**, 11.245293 seconds.
- `bundle exec rubocop` on both modified purgers and their two test files:
  two invocations, 2 files each, no offenses. `git diff --check` exited 0.

The proposed three-column issuance-authority snapshot remains awaiting explicit
shape approval. Its generated, unapplied migration was removed with the exact
Rails destroy command before this work. No new DDL or shared database operation
was performed here. Live-owner replay-barrier retirement remains incomplete.
Full suite and E2E were excluded as instructed; the overall goal remains active.
