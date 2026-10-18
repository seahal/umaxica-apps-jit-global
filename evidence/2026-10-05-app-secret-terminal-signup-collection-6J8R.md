# Terminal signup collection and lifecycle traversal

Observed 2026-10-05 (UTC), through 14:28 UTC, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted implementation,
test and documentation changes. Unrelated work was preserved. No reset, worktree,
push, deployment, shared destructive application or E2E execution occurred.

## Changes and callers

- `ClientSecretLifecycleJob#perform` now has bounded fixed-horizon credential
  and signup continuation phases. Retained credentials, unresolved claims and
  live signup allocations do not stop traversal to later source rows. Existing
  claim/retirement operations retain their authority and locking checks. Each
  credential batch delivers source audits before attempting physical collection.
- `ClientSecretIssuanceCollectionJob#perform` invokes the existing purger's new
  `call_terminated_signup!` entry for retired, unactivated signup allocations.
  Source Client, matching Ticket signup flow and Source issuance are locked in
  that order. Only CANCELLED/EXPIRED/FAILED flows qualify. Candidates, receipts,
  payload, retention after flow/purge deadlines, holds and durable terminal and
  credential-purge audits gate deletion. Atomic DELETE preserves the purge outbox.
- An allocation expired before later signup cancellation retains its original
  expiry audit. The allowance requires unconfirmed allocation facts and immutable
  expiry no later than the Source discard timestamp; it does not fabricate a
  later cancellation audit.
- Updated issuance and credential diagrams, transition inventory and security
  documentation in the same change. The old persistence proposal explicitly
  identifies its superseded consumed_at discussion.

No additional operational duration or parallel credential model was introduced.
The user accepted the four Secret lifetimes previously; tests below explicitly
set approved values or isolated short intervals as appropriate.

## Executed verification

All Rails commands use `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb`
against its existing OID/owner-guarded `codex_integrity_20261005recovery_*` fleet.
Actual PostgreSQL version was 17.7 at `10.89.2.3:5432`.

- Generated only the missing test artifact with
  `generate test_unit:job ClientSecretLifecycle`; removed its generated placeholder
  before verification. The existing production job was reused.
- Credential traversal reproduction: `test test/jobs/client_secret_lifecycle_job_test.rb`,
  seed 18655, 1 run/2 assertions/1 failure. A held first credential prevented later
  eligible credential deletion. After the continuation change, that job file,
  outbox recovery and audit delivery passed: seed 12744, 10 runs/91 assertions.
- Signup traversal reproduction: `test test/jobs/client_secret_lifecycle_job_test.rb
  --include '/signup_continuation/'`, seed 17523, 1 run/3 assertions/1 failure.
  A live first allocation prevented retirement of a later durably canceled signup.
  An earlier seed 45026 arrangement used discard rather than status transition;
  corrected it to public `transition_to!("CANCELLED")` and asserted the terminal
  status before the valid reproduction. After the change, the three related files
  passed: seed 62143, 11 runs/97 assertions.
- Terminal omission reproduction: completed issuance purger test with
  `--include '/canceled_signup_omission/'`, seed 28244, 1 run/0 assertions/1 error
  because the collection entry did not exist. A subsequent non-retired terminal
  case, seed 10702, exposed Infinity/Time comparison failure; explicit retention
  guards now return pending. The canceled omission test additionally verifies
  audit refusal, proof waiting, legal hold and real allocation collection job.
- Classification matrix: completed issuance purger test with
  `--include '/canceled_expired_and_failed/'`, seed 54705,
  **1 run/69 assertions, no failures/errors/skips**. It tests the nine combinations
  of CANCELLED/EXPIRED/FAILED and 0/1/2 candidates, including pending and confirmed
  candidate partitions. Public retirement, audit delivery and credential purgers
  are exercised; allocation collection refuses before candidate purge delivery.
- Expiry-before-cancellation reproduction: completed issuance purger test with
  `--include '/allocation_expiry_preceding/'`, seed 64493, 1 run/2 assertions/1 failure
  (undelivered instead of purged). After the reason-binding fix, completed issuance
  purger and lifecycle job tests passed: seed 55837,
  **14 runs/217 assertions, no failures/errors/skips**, 10.748766 seconds.
- Five-file regression before the final reason-binding fix:
  `test/jobs/client_secret_lifecycle_job_test.rb`,
  `test/operations/client_secret_completed_issuance_purger_test.rb`,
  `test/jobs/client_secret_issuance_collection_job_test.rb`,
  `test/jobs/client_secret_outbox_recovery_test.rb`,
  `test/jobs/client_secret_audit_delivery_job_test.rb`: seed 58255,
  **26 runs/345 assertions, no failures/errors/skips**, 11.345508 seconds.
- Current lifecycle input boundaries separately passed: seed 12020,
  3 runs/78 assertions. Batch values 0/1/2/499/500/501, invalid types/phases,
  negative/noninteger/reversed cursors, equality and adjacent valid cursor pairs
  are exercised through public job execution.
- Actual OIDC canonical issuance and receipt/purge regression:
  `test test/integration/oidc_initiated_sign_in_completion_test.rb:71`, seed 62265,
  **1 run/50 assertions, no failures/errors/skips**, 11.670507 seconds. It establishes
  a real root token and receipt through HTTP and verifies receipt retention,
  hold, durable audit, rollback and eventual lifecycle collection without token loss.
  This run preceded only the expiry-reason fix, which does not change successful
  receipt collection.
- RuboCop on the four final changed implementation/test files passed with no
  offenses. Earlier complexity violations were resolved by domain predicate and
  audit-selection extraction; no threshold or exclusion changed. Five-file checks
  also passed before the final expiry-reason fix. `git diff --check` exited 0.

This is concrete progress, not completion evidence for Phase 1. Receipt scan
fairness, bounded replay-barrier retirement, remaining failure/race/deadline
coverage and schema-drift resolution still require implementation or verification.
No full-suite run was used; the user accepts individual relevant tests.
