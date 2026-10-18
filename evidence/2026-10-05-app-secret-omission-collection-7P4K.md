# App Secret omitted allocation collection

## Additional authority and audit guards — 2026-10-05T12:27:03+00:00

HEAD remained `e8f2371bc5cbefd2087c728aeeef4e318463d33f`, relevant worktree
uncommitted. Added public Minitest examples for an explicit positive-Infinity
session retention sentinel, subsequent real session revocation, legal hold/release
and missing omission audit despite a completed signup audit. The existing test
handle 54341 was re-polled and is still pending, so these examples have no claimed
Minitest result.

The first sentinel observation incorrectly expected ordinary ClientToken creation
to persist Infinity. The actual refresh-token callback assigns the existing finite
refresh lifetime on creation, so the collector returned pending and the observation
failed its expected-result assertion. This was not an observed early deletion.
Inspected RefreshTokenable and then used the existing public schedule_retention!
API to construct an explicit sentinel fixture in the task DB; no application
callback was disabled and no session lifetime setting was changed.

`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb runner
/tmp/umaxica-secret-omission-infinity-hold-observation.rb` then exited 0. It verifies
dependent refusal for Infinity, invokes the actual token revoke! method, observes
the writer deadline plus explicit one-second proof retention, creates a real legal
hold, verifies held refusal, releases the hold and physically collects the
allocation. Output: unbounded session retained, revocation observed, legal hold
respected, collected after deadline and session record retained, all true. These
are retention fixtures, not canonical root issuance or browser authentication.

`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb runner
/tmp/umaxica-secret-missing-omission-audit-observation.rb` exited 0. A persisted
zero-count signup fixture has a durable matching signup_completed event but lacks
issuance_omitted. The public collector returns undelivered and retains the
allocation without recording issuance_purged. Output: missing omission refused,
allocation retained and no deletion marker, all true. This fault fixture verifies
audit completeness, not an actual signup completion journey.

The scripts use the guarded task fleet and explicit retention_after: 1.second.
No raw Secret, digest, cookie or temporary runtime DDL is involved. The test file
passed scoped git diff --check. Final `bundle exec rubocop
test/operations/client_secret_completed_issuance_purger_test.rb` passed: one file,
no offenses. Actual
completed-signup flow locking, enforcement holds, temporal equality and concurrent
revocation/collection still need coverage. These observations do not resolve those
remaining requirements or the pending Minitest run.

Observed at 2026-10-05T12:14:35+00:00 (UTC). HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f`; relevant code, tests and documents are
uncommitted. All runtime observations used the existing guarded
`/tmp/umaxica-secret-recovery-db-task.rb` fleet. No shared database, other surface,
other owner's process or external application was changed.

## Implemented public path

`ClientSecretIssuancePurger.call_omitted!` extends the existing collector rather
than creating a second issuance model. It requires a persisted allocation and an
explicit positive finite proof-retention duration. It locks Source Client, the
original Ticket session/signup authority and the allocation. It checks omitted
state, no candidates, completion of signup when bound, current holds, exact source
omission/completion facts, delivery acknowledgment and Chronicle presence.

Retention starts after the latest allocation/completion fact and authority
deadline. Signup reuses flow expires_at; ClientToken reuses actual discard_at.
Positive Infinity session discard retains the allocation until session retirement.
An existing authority with a missing/malformed deadline fails explicitly. Absent
authority cannot authorize a continuation; durable source completion and audit
still gate deletion. DELETE and the zero-count issuance_purged replay barrier share
the Source transaction. Existing unconfirmed collection keeps its original entry.
The periodic lifecycle job calls the omission entry with the existing explicit
APP_SECRET_PROOF_RETENTION_SECONDS setting. No new operational default was added.

## Executed observations

- The proposed collector was initially absent: public runner calls failed with
  NoMethodError. The explicit API was refined to call_omitted!, whose absence was
  also observed before implementation. A Minitest was written first and remains
  waiting on the repository's common test lock.
- The first rollback observation exposed stale Ruby destruction state after a
  database rollback. Retry now fetches a fresh persisted allocation from the DB.
  A subsequent attempt reused an already acknowledged fixture and therefore
  failed its missing-audit precondition; the actual eligible row was collected.
  No success was inferred from that failed observation. A new fixture then ran
  the complete sequence.
- `/tmp/umaxica-secret-omitted-issuance-full-observation.rb` verifies immediate
  retention refusal, actual writer deadline, missing-audit refusal, delivery,
  DELETE/outbox inside a real Source transaction, rollback of both and a fresh-DB
  retry. Exit 0: allocation collected true; replay barrier retained true.
- `/tmp/umaxica-secret-omitted-issuance-lifecycle-observation.rb` executes the actual
  periodic job before and after the explicit one-second proof deadline. Exit 0:
  allocation collected true; replay barrier retained true. Repeated after adding
  the original-authority lookup; exit 0 with the same observations.
- Initial bound-session setup incorrectly used expires_at on ClientToken and
  failed UnknownAttributeError before persisting the token. Inspected the actual
  ClientToken and TokenStatusManagement contracts, corrected setup and collector
  to discard_at. `/tmp/umaxica-secret-omission-binding-observation.rb` then verifies
  retention through a real finite session deadline plus one-second proof
  retention, later collection and preservation of the session record. Exit 0:
  all three true. Token creation is an established-session fixture for collection,
  not evidence of canonical root issuance or authentication.

Runner command prefix was `bundle exec ruby
/tmp/umaxica-secret-recovery-db-task.rb runner <observation-file>`. Lifecycle
observations explicitly supplied APP_SECRET_PURGE_DELAY_SECONDS=86400,
APP_SECRET_OUTBOX_RETENTION_SECONDS=3600 and
APP_SECRET_PROOF_RETENTION_SECONDS=1. The standalone public collector observations
passed retention_after: 1.second explicitly. These are isolated test values, not
approved operational values. No plaintext candidate or new credential is generated
for the omitted fixtures.

Rails documents that transaction rollback does not restore Ruby object instance
data and that transaction atomicity is per connection. Checked the primary
[Active Record transaction documentation](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html)
before correcting the retry observation; no reflection or test-only wrapper was
introduced.

## Checks and limits

`bundle exec rubocop app/operations/client_secret_issuance_purger.rb
app/jobs/client_secret_lifecycle_job.rb
test/operations/client_secret_completed_issuance_purger_test.rb`: final three
files passed, no offenses. Earlier size/style findings were resolved by ordinary
private responsibility separation and formatting; no threshold was changed.
Scoped git diff --check passed.

`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test
test/operations/client_secret_completed_issuance_purger_test.rb` remains live via
handle 54341, re-polled with no output. No Minitest pass count is claimed. Tests
cover public omission collection, rollback/retry, bound session lifetime and
retention boundary/sentinel input; their results remain unverified.

These observations use persisted isolated omission fixtures, not the HTTP A=20
registration journey. Completed signup collection, positive-Infinity session
retirement, holds, exact temporal/race boundaries and periodic fairness still need
additional verification. Uncompleted signup omissions remain protected; their
terminal cleanup is unfinished. Confirmed batches and eventual replay-barrier
retirement remain unfinished. The configured proof-retention proposal still needs
operational approval. No shared-DB application occurred.
