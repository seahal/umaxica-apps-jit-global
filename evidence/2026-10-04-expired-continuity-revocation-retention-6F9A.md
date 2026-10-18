# Expired continuity revocation and terminal retention

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and concurrent unrelated work. No deployment, schema change or shared database operation.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, preparation selected the isolated APP ticket copy, one worker. Rails commands were sequential.

A public token-revocation regression reproduced rollback when admitted Auth continuity had reached
its expiry: AuthCeremonySession#revoke! required active continuity and raised, aborting the token
revocation transaction. Revocation now closes nonterminal continuity even after its TTL. Admission,
authentication-evidence recording, completion and cancellation retain their original active-state
requirements. This adds no authentication authority or transport fallback.

The test covers the nearest microsecond before, at and after continuity expiry with a shared explicit
decision time. Each case revokes the token, its pending parent and continuity, and rejects subsequent
authentication evidence. Token/continuity/model and credential-transition tests passed:
**60 runs, 355 assertions, no failures/errors/skips**, seed 14935.

A second regression reproduced early physical deletion of a parent with an old expiry but a recent
cancel/revoke timestamp. Parent cleanup now requires its expiry and every present terminal timestamp
to be outside retention. Recent terminal facts retain the whole cohort; restrictive FKs remain.

`bin/rails test test/operations/identity_step_up_ceremony_transaction_purger_test.rb test/jobs/step_up_ceremony_transaction_purge_job_test.rb test/models/concerns/token_status_management_test.rb test/models/auth_ceremony_session_test.rb test/services/credential_security_transition_test.rb`
passed: **67 runs, 396 assertions, no failures/errors/skips**, seed 5088. RuboCop passed on the four
changed files and `git diff --check` passed.

These are model/operation boundary checks in isolated transactions. Independent-connection races,
actual logout browser behavior, database fault injection and all-surface expiry revocation remain
unverified. Full R01–R16 remains incomplete, Passkey candidate shape approval remains pending,
browser checks are user-owned and OTP logging remediation remains excluded.

## Actor-specific continuation

The expiry revocation regression now runs on real Client/Visitor/Operator tokens and each surface's
matching parent and continuity models. Before/at/after expiry cases close all three records and
reject later authentication evidence. No Auth root credential is injected. The three-file selection
passed **60 runs, 391 assertions, no failures/errors/skips**, seed 61347.

The combined nine-file selection containing the three required root-login gates, token/continuity/
credential-transition tests, parent purger/job and the full TOTP registration HTTP file passed:
**132 runs, 956 assertions, no failures/errors/skips**, seed 1517. It used the same owned manifest,
isolated APP ticket preparation and one worker. RuboCop passed on the changed test and
`git diff --check` passed. This supersedes the earlier all-surface expiry revocation verification
gap at the public model boundary; it does not prove all-surface browser logout or concurrent races.
