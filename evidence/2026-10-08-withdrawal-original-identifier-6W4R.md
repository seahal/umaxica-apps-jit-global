# Original identifier retention during withdrawal

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted identifier, OTP,
history and maintenance changes affect these results.

Two new persisted APP/COM tests first reproduced SQL binding immutability errors in withdrawal
synthetic-PII rewriting: seed 32228, two runs, zero assertions, two errors. This was a genuine
implementation defect: withdrawal attempted to replace a finalized lookup digest before dead
history could fingerprint original PII.

Independent Email/Telephone model retirement writers now lock the freshly loaded terminated
owner before the Source row, use the owning database clock, preserve encrypted PII/digests and
failure/lock state, clear the legacy challenge and schedule collection. Longer explicit Source
retention is preserved. An infinite owner deadline does not authorize deletion. Logical retirement
creates no history; later permitted identifier-only purge stores a fingerprint matching original
PII and preserves the Identity. No production or shared data was erased.

`bin/rails test test/operations/withdrawal_personal_data_anonymizer_test.rb
test/jobs/dead_identifier_retention_test.rb test/jobs/retention_purge_job_test.rb
test/jobs/retention_purge_legal_hold_test.rb` passed: 31 runs, 183 assertions, zero
failures/errors/skips, seed 17851. This includes APP/COM finalized binding preservation, later
original-identifier history matching, longer retention, failed-attempt preservation, actual
persisted Visitor credential revocation, ORG whole erasure and retained/legal-hold job behavior.

The old Client synthetic-value expectation was updated to the new original-identifier contract.
The mocked Visitor case was replaced with real records, not skipped. Missing Visitor Secret
reference rows were fixed in setup using semantic constants; no validation was relaxed.

ADR, the four APP/COM Contact status diagrams and their 29 retirement inventory rows were updated.
Full-goal verification remains incomplete. This evidence does not assert Definition of Done.

Existing APP/COM model destruction now admits physical erasure only after both fresh retention
deadlines and absence of active legal/enforcement holds. It removes only that owner's histories
after Source-dependent archive/delete callbacks and before parent DELETE in one local transaction.
The initial four-case erasure file reproduced two FK errors and two expected-refusal mismatches
(seed 46886). Real Source children subsequently exposed a Client callback-order error; moving
the final callback below all associations fixed it without changing restrictive FKs. A protected
Contact rolls back prior Source archives. A fault after actual idempotent cross-DB cleanup
preserves the owner/history, and an identical retry succeeds; remote deletes are not claimed
to roll back.

`bin/rails test test/models/identity_dead_history_erasure_test.rb
test/models/dead_identifier_destroy_test.rb test/operations/withdrawal_personal_data_anonymizer_test.rb
test/jobs/dead_identifier_retention_test.rb test/controllers/auth/com/up/emails_controller_test.rb`
passed: 53 runs, 536 assertions, zero failures/errors/skips, 16 processes, seed 41208.
The protected, recoverable, legal-hold, real children, peer-history isolation and fault/retry cases
passed. The actual COM replacement-email HTTP journey retains its halted candidate and Identity
without premature history (its initial focused run also passed: one run, 20 assertions, seed 57226).
Focused six-file lint passed. RetentionPurgeJob still keeps APP/COM Identity tombstones; no
automatic physical erasure or public History interface was added.

An overdue owner initially produced an invalid Source retention order (two errors, seed 65495):
logical retirement happened now but inherited a past purge deadline. The named writers now anchor
the ordered window at the locked current retirement time while preserving longer deadlines; the
operation file passed ten runs, 93 assertions, seed 11125.

The real due-account job then reproduced premature completion (two failures, seed 55626): it
left original identifiers present while setting the terminal marker. Account collection now locks
and reloads the owner, rechecks retention/holds, retires and physically collects due Contacts, and
marks completion only when no retained identifier remains. Local Source/history/marker writes share
one transaction; completion occurrences follow the local commit. A longer retained Contact prevents
a false shredding receipt and a later eligible run completes collection. Three old fixtures with
retention timestamps preceding created_at were corrected, retaining normal model validation.
One exact deadline assertion was corrected to read PostgreSQL's stored microsecond timestamp,
not compare it with an unstored nanosecond input. No deadline tolerance was introduced.

The four-file job/hold/retirement matrix passed 37 runs, 229 assertions, zero failures/errors/skips,
seed 10504. Broader regression and lint results remain pending for these latest changes.
