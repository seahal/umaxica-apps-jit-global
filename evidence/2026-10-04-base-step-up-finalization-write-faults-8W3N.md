# Base step-up finalization write failures

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

`bin/rails test test/operations/identity_step_up_ceremony_freshness_committer_test.rb`
passed **5 runs, 54 assertions, no failures/errors/skips**, seed 59483.

Three added cases inject a statement failure through Rails SQL notifications after updating,
respectively, the Base token, step-up parent, and Auth continuity. Each observes rollback of token
freshness, parent consumption, and continuity completion together. Retrying the same opaque result
then succeeds with the original verification timestamp. Existing successful replay and credential
revocation cases also pass. Verification evidence is synthetic; these cases do not verify a
WebAuthn signature or a genuine browser session.

RuboCop inspected the freshness committer test, transaction purger test, and continuity concurrency
test: three files, no offenses. No implementation, schema, or shared database changes were needed
for this test extension.

The injected statement failures do not simulate lost database connections, commit acknowledgement
loss, independent concurrent logout, or cross-database credential registration commits. Those
remaining acceptance cases are not established by this record. Browser verification remains
user-owned; OTP logging remediation remains excluded.
