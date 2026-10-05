# Secret migration replay and destructive rebuild

Performed 2026-10-04, approximately 05:50–05:58 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 426 dirty paths
at the final capture, including concurrent work. Results include uncommitted
changes and are not CI results.

## Fresh build

The guarded provisioning wrapper created new task-owned PostgreSQL databases
and identity manifests, refusing existing names and checking owner/OID/comment.
No existing database was reset or dropped.

`bundle exec ruby /tmp/umaxica-history-final-db-task.rb runner
/tmp/umaxica-app-secret-history-final.rb` replayed the configured migration paths
through the fixed Rails public `DatabaseTasks.with_temporary_pool_for_each`
interface, explicitly selecting test app_zenith and app_ticket. It used each
selected pool's migration context without the schema-loading initialize step.
The destination databases were initially empty of application tables.

`bundle exec ruby /tmp/umaxica-history-final-db-task.rb runner
/tmp/umaxica-app-secret-history-verify.rb` inspected actual table destinations:

- codex_integrity_20261004history_app_zenith: 369 recorded migrations; Client,
  credential, issuance and source outbox tables present.
- codex_integrity_20261004history_app_ticket: 94 recorded migrations; success
  receipt present with operation, credential, Client, flow and root Token references.
- New credential client_id is NOT NULL. public_id, lookup_digest and
  claim_operation_id have unique indexes; the claim shape CHECK is present.
- Legacy kind/status lookup tables are absent. Credential columns exclude old
  kind, usage policy, counters, safe prefix and consumed_at.

Both commands exited 0. This verifies the currently implemented shape; it does
not approve or implement the pending claim-flow/provenance/delivery refinements.

## Rebuild from old schema and data

`bundle exec ruby /tmp/umaxica-old-secret-proof-db-task.rb runner
/tmp/umaxica-app-secret-old-before.rb` replayed Zenith only through the actual
preceding version 20261003202225 in a separate new disposable fleet.
It confirmed the legacy user_id, kind/status FKs and variable counters existed.

`bundle exec ruby /tmp/umaxica-old-secret-proof-db-task.rb runner
/tmp/umaxica-app-secret-old-apply.rb` inserted a synthetic Client and one legacy
credential, captured counts for every unrelated application table, and replayed
the remaining configured Zenith migrations through the same explicit pool API.
Final result, exit 0:

- Old credential rows before: 1; new credential rows after: 0.
- Legacy kind/status lookup tables removed.
- Client retained.
- Counts preserved for 112 unrelated application tables in this disposable DB.

Synthetic setup DML accommodates the historical schema; it is not an application
write path or a compatibility implementation. No raw Secret or real credentials
were used. The rebuild intentionally cannot restore discarded legacy values.

## Failed diagnostic attempts and limits

Initial `db:migrate` exited 0 but fixed Rails initialize_database loaded existing
schema dumps, so it was not accepted as migration replay evidence. An initial
direct migration-context call used the framework's default migration connection;
its success was not accepted as proof of the intended Zenith/Ticket placement.
Those attempts affected only separate newly provisioned disposable fleets.
The corrected run used a fresh fleet and verified current_database on both targets.

Other setup attempts failed for deprecated connection access, a nonexistent target
version, a private framework helper, and use of the current Client model against
the legacy credential schema. They were corrected without changing product code,
framework settings, migrations or test gates. None counts as a TDD Red result.

NOT_RUN here: full-suite behavior checks, data-populated com/org regression,
all-tables content equivalence, production application, and schema drift task.
The drift task writes repository dumps; it was not run against the concurrent
dirty tree in this slice. No generated dump was hand-edited. Existing migration
down explicitly raises IrreversibleMigration; recovery means recreating a
disposable environment, not recovering intentionally discarded credentials.

Secret delivery, canonical login connection, Chronicle dispatch and audited
physical purge remain incomplete. This evidence proves DDL construction only.
