# WU-7 local preference purge execution ticket

Status: not approved and not executed. This ticket covers a future invocation against the local test
com setting and Chronicle databases only. It does not authorize a recurring task, development,
production, Neon, or any other database.

## Measured scope

At 2026-10-30T23:53:13.646502Z, the com setting database clock reported two preference parents;
zero had `last_issued_expires_at + 30 days` at or before that clock. Consequently no candidate had a
com Chronicle subject or actor reference, and zero rows were observed eligible after that reference
check. These are point-in-time observations, not a reservation: rerun the count immediately before
any operation. Other holds or external references have not been exhaustively inventoried.

A later read-only measurement at 2026-10-31T00:44:13.835445Z found the same counts: two parents
and zero expired candidates. The verified targets were `test_com_setting_db` and
`test_chronicle_db`; see `evidence/2026-10-31-wu7-purge-count-G6M3.md`. Remeasure immediately
before any proposed execution.

A read-only catalog inspection found 15 local setting foreign-key source tables for the parent;
all match associations declared by the purger. Its Chronicle association is in the separate
Chronicle database. This does not inventory cross-database references without foreign keys or
external holds; see `evidence/2026-10-31-wu7-purge-reference-inventory-V5K8.md`.

## Proposed operation and risks

Invoke `PreferenceLifecycleJob.perform_now` once in the local test environment, using the existing
retention suspension control and the job's own deadline, audit-reference and lock checks. The job
can delete eligible parents and dependent com preference rows; it does not delete audit history.
The eligible set may change between measurement and execution. The subject and actor audit checks
span separate databases; callbacks or SQL writers that bypass the coordinated locking protocol are
not protected by it. Unknown external holds may make even an apparently eligible row unsafe to
remove. Automatic scheduling is outside this ticket.

## Recovery prerequisites

Before execution, verify the actual database names and target environment without printing
credentials. Create separate PostgreSQL custom-format backups of the target com setting and
Chronicle test databases; record backup locations and SHA-256 hashes, and verify that `pg_restore
--list` can read each. Rehearse restoration into separate scratch databases and verify the relevant
parent, child and audit records. The two independent snapshots are not an atomic cross-database
snapshot: a consistent restore requires quiescing writers while both are captured and during any
recovery. Keep the snapshots until the owner confirms recovery is no longer needed.

An initial separate-database backup and scratch restore rehearsal was performed on 2026-10-31;
the archives, hashes, scratch database names and matching selected data are recorded in
`evidence/2026-10-31-wu7-purge-recovery-rehearsal-F7W2.md`. Complete writer quiescence was not
established, so those snapshots do not establish a consistent cross-database recovery point.
Establish quiescence and capture fresh snapshots before any approved operation.

## Approval and execution gate

Obtain explicit approval for the remeasured candidate count, identified holds, recovery rehearsal,
local test database targets and one-time execution before invoking the job. If the count, target,
hold inventory or recovery plan changes, remeasure and obtain approval for the changed proposal.
Record the actual invocation and before/after results in `evidence/`. Do not infer approval from this
file or from authorization of the earlier schema migration.
