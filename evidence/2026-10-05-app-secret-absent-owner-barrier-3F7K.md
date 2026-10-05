# Absent-owner issuance barrier collection

Observed 2026-10-05 (UTC), through 14:44:38+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted purger, scan,
test and documentation changes. No Client deletion or shared DB operation was
performed. The test models an already absent owner through an independent source
audit reference, rather than deleting a Client to arrange the case.

`ClientSecretAuditOutboxPurger.call!` now retains issuance replay barriers while
their Client exists. With an absent Client, the ordinary delivery, retention,
dependency, enforcement and Chronicle guards still apply before collection.
Manual and Passkey reservation operations require the owning Client row lock;
they cannot accept replay for an absent owner. No live-owner authority is inferred
to be expired from age alone.

`ClientSecretAuditOutboxPurgeJob` now includes barriers in its fixed-horizon cursor
scan. Existing cursor continuation advances past retained live-owner barriers.
Updated the outbox diagram, transition inventory and security document together.

Commands used `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test`
on the OID/owner-guarded `codex_integrity_20261005recovery_*` fleet.

- Red: `test/operations/client_secret_audit_outbox_purger_test.rb
  --include '/deleted_Client_replay/'`, seed 24705: 1 run/3 assertions/1 failure;
  expected collection but received replay_barrier despite absent owner.
- Green: that full file and
  `test/jobs/client_secret_audit_outbox_purge_job_test.rb`, seed 24795:
  **7 runs/41 assertions, no failures/errors/skips**, 5.987950 seconds. Tests retain
  existing-owner barriers and credential dependencies and traverse retained rows
  without losing independent Chronicle history.
- RuboCop on the purger, scan job and purger tests: 3 files, no offenses.
  `git diff --check` exited 0.

This is partial barrier retirement. Live-owner manual/session and Passkey
registration operations still need bounded authority-aware retirement. No new
TTL, compatibility mode, parallel model, runtime DDL or auth bypass was introduced.
The full implementation goal remains active. Full-suite and E2E were not run.
