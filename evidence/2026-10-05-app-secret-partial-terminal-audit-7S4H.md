# App Secret partial terminal audit delivery

Executed on 2026-10-05 UTC against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f`, with uncommitted implementation,
tests and documentation affecting the result. The guarded runner used the
task-owned PostgreSQL 17.7 fleet from
`tmp/app-secret-20261005recovery-manifest.json`.

The actual one-row delivery job committed the issuance cancellation audit while
leaving the candidate's discarded audit undelivered. The public credential
purger then deleted the candidate incorrectly. Focused command:
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb --include '/payload failure/'`.
Red result: seed 32721, 1 run, 4 assertions, one failure, 0.693468 seconds;
expected `undelivered`, observed `purged`.

The purger now requires a credential-specific discarded event in addition to
the allocation terminal event for unconfirmed non-withdrawal candidates. Every
required event must be acknowledged and match its durable Chronicle record.
Confirmed and withdrawal cases retain their credential-specific evidence.
No persisted or wire format changed.

Command:
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb test/jobs/client_secret_lifecycle_job_test.rb`.
Final result: seed 50763, 12 runs, 197 assertions, zero failures, errors or skips,
1.974529 seconds. Partial delivery holds the candidate; full delivery permits
real lifecycle deletion, surviving purge-event delivery and duplicate-safe retry.
An earlier green run before extracting the audit-completeness predicate was
seed 54616, also 12 runs and 197 assertions, 1.738653 seconds.

`bundle exec rubocop app/operations/client_secret_credential_purger.rb test/jobs/client_secret_audit_delivery_job_test.rb`
passed after extracting the private predicate to retain the existing complexity
limits. Tests use public operations; no threshold was lowered.
`git diff --check` passed. No E2E or full suite was run, as instructed.
Manual form replay, explicit delivery reattempts and remaining authority-proof
retirement are still unfinished; this result does not imply Phase 1 completion.
