# Secret purge bypasses undelivered audit

Performed 2026-10-04, 05:47–05:49 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 420 dirty paths
at capture, including concurrent work. These results include uncommitted changes.

## Runtime reproduction

Executed `bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb runner
/tmp/umaxica-secret-purge-source-probe.rb`, exit 0. Both credential and Chronicle
connections were required to use the task-owned
`codex_integrity_20261004registration_*` disposable fleet.

The probe created an active Client, canceled manual issuance and due unconfirmed
candidate, then recorded `secret.discarded` in the same Zenith transaction.
Chronicle had no matching event. It called the actual public
`RetentionPurgeJob.perform_now(batch_size: 1)` and observed:

- Job completed; candidate no longer existed.
- Source event still existed; delivered_at remained absent.
- Chronicle still had no matching event.

The probe rolled back its enclosing Zenith transaction. No raw credential, digest,
actor identifier or event identifier was printed. The generic job ran only on the
disposable fleet; this was not a shared or production DB operation.

`RetentionPurgeJob` includes ClientSecretCredential among its generic models and
uses due-row `delete_all`. This runtime result contradicts the required app Secret
contract: preceding terminal audit must be saved in Chronicle before physical
deletion. A successful job exit is not successful audited recovery.

## Implementation consequence

Audited app Secret purge remains incomplete and blocks accepting that workstream.
Its physical deletion must have one owner, verify prior authoritative Chronicle
records, and commit deletion with a surviving secret.purged source event in the
same Zenith transaction. Existing com/org recovery must remain intact.

No replacement purge, Chronicle projection, schema or security bypass was added
by this reproduction. The pending Chronicle delivery shape is not accepted merely
because this defect exists. NOT_RUN: repaired purge, delivery/crash recovery,
canonical login receipt reconciliation, full suite and deployment.
