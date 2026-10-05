# Signup payload failure collection

Executed on 2026-10-05 at 16:20 UTC against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f`, with uncommitted implementation,
test and documentation changes. Verification used the guarded task-owned
PostgreSQL 17.7 fleet in `tmp/app-secret-20261005recovery-manifest.json`.

The public signup reservation, preparation and payload-failure retirement
operations created a discarded two-candidate batch. After later flow cancellation,
actual audit delivery and candidate deletion, allocation collection incorrectly
returned `undelivered`: it searched for the later flow reason and excluded the
original payload-failure cancellation event.

Red command:
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/operations/client_secret_completed_issuance_purger_test.rb --include '/signup payload failure/'`.
Seed 30669, 1 run, 3 assertions, one failure, 0.793884 seconds.

The existing collector now recognizes the already-defined `payload_unavailable`
reason when the immutable cancellation equals the discard timestamp. It requires
the matching allocation event, candidate references, Chronicle identities and
candidate purge acknowledgments. Original Ticket terminal locking, proof
retention and holds still apply. No event, reason enum, field or schema changed.

Related command:
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/operations/client_secret_completed_issuance_purger_test.rb test/jobs/client_secret_issuance_collection_job_test.rb`.
Seed 13964, 16 runs, 190 assertions, no failures/errors/skips, 10.861910 seconds.
After adding live-flow and pre-retention assertions, the focused command passed
with seed 2092, 1 run, 7 assertions, no failures/errors/skips, 0.838449 seconds.
The test controls the existing public Source database-time boundary for the
post-retention observation; database persistence, Ticket locks, audit delivery
and DELETE are real. It does not claim wall-clock passage of operational retention.
The saved Passkey remains present; the original retirement reason is unchanged.

RuboCop passed for the collector and its completed-issuance test after correcting
assertion spacing, line length and relation batching. `git diff --check` passed.
The local Chronicle `security` fixture's 365-day policy is separate from the four
approved application lifetimes. No shared database, E2E or full suite was used.
Explicit reattempt UI and replay contracts remain unfinished.
