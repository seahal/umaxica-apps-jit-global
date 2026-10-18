# Step-up purge reference failure

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and concurrent unrelated work. No deployment or schema change.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, isolated APP ticket preparation, one worker.

`bin/rails test test/operations/identity_step_up_ceremony_transaction_purger_test.rb` failed:
**1 run, 0 assertions, 1 error**, seed 42845. An expired parent eligible for its
seven-day purge remains referenced by a more recently expired Auth continuity record. The existing
parent-only DELETE raises an FK violation against `client_auth_ceremony_sessions` before returning.
The test uses model APIs and isolated transaction-owned rows; no schema or shared data was changed.

The purger's comment that ceremony parents have no dependent records is stale. Current APP parents
also have restrictive references from StepUpSession, Passkey/TOTP children and TOTP candidates;
COM/ORG have their actor-specific references. A complete correction must respect each child's
retention window, delete eligible children before parents on the same writer connection, retain
parents with retained children and ensure cleanup cannot revive consumed authority. Removing FKs
or rescuing this exception as successful cleanup is not acceptable. The regression intentionally
remains red until the lifecycle correction is implemented; it is not a skipped or placeholder test.

Full R01–R16 is incomplete. Passkey candidate shape approval remains pending; OTP logging is
excluded and browser verification is user-owned.

## Correction

The purger now locks eligible parents and evaluates the fixed actor-specific dependent models on
the same ticket writer connection. It retains the entire parent cohort if any reference remains
inside retention. Eligible Auth continuity, registration children, APP TOTP candidates and
StepUpSession rows are removed before their parent in one transaction. StepUpSession also honors
its existing explicit purge_eligible_at, including Infinity. Recent completion/cancellation/
revocation or candidate consumption preserves the record. Restrictive FKs remain; no exception is
swallowed and no token or audit record is collected by this operation.

`bin/rails test test/operations/identity_step_up_ceremony_transaction_purger_test.rb test/jobs/step_up_ceremony_transaction_purge_job_test.rb test/operations/identity_totp_ceremony_transaction_purger_test.rb`
passed: **7 runs, 40 assertions, no failures/errors/skips**, seed 20970. Cases cover retained
continuity, eligible continuity on all three surfaces, one-microsecond retention boundaries,
APP encrypted TOTP candidate/child removal, explicit StepUpSession retention and unchanged owning
token, and repeated purge returning no new deletion. RuboCop passed on the two changed files.

This supersedes the reproduced single-reference FK failure. Independent-connection cleanup/revocation
races, fault injection, and every registration-child partition remain unverified. Parent and child
locking can require transaction retry on a database deadlock; failure is explicit and rolls back
the cohort. The complete R15 lifecycle and full ledger are not yet claimed finished.
