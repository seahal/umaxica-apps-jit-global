# App Secret payload failure boundaries

Executed on 2026-10-05 UTC against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted implementation,
test and documentation changes. Unrelated worktree changes were preserved.

Command:
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/operations/client_secret_presentation_issuer_test.rb`.
The runner verified the task-owned PostgreSQL 17.7 database fleet identified by
`tmp/app-secret-20261005recovery-manifest.json` before booting Rails.

Final result: seed 40834, 3 runs, 47 assertions, zero failures, errors or skips,
0.868564 seconds. Missing and malformed encrypted payloads reject presentation,
preserve candidate identities and counts, and reject unpresented confirmation.
Preparing a missing payload with existing candidates does not generate replacements.
Explicit authorized cancellation discards the unconfirmed candidate and removes the
payload; an explicit different operation can then reserve a new issuance.

`bundle exec rubocop test/operations/client_secret_presentation_issuer_test.rb`
passed after correcting three assertion-spacing offenses. `git diff --check`
passed. These checks did not run the full suite.

The initial run (seed 14195, 3 runs, 19 assertions, one failure) used a stale
issuance object when clearing the payload: its unchanged nil attribute did not
write the prepared database value. The test now reloads before applying the
failure fixture. No production behavior was changed to accommodate the test.

An additional test copies another Client issuance's authentic encrypted payload
into the target issuance. Presentation and confirmation reject it without creating
candidates or audit events; the source issuance remains independently presentable.
The same command then passed with seed 59498, 4 runs, 58 assertions, zero failures,
errors or skips, in 1.032468 seconds. RuboCop's additional multiline-assignment
format offense was corrected with its file-scoped autocorrection; the corrected
file passed. No semantic change was made by the formatting correction.

Protected HTTP retirement was subsequently verified with
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/integration/app_secret_login_journey_test.rb --include '/unavailable manual payload/'`.
Result: seed 47250, 1 run, 24 assertions, no failures, errors or skips,
1.393225 seconds. Both missing and malformed payloads return 410, record
cancellation, erase the payload, discard the unconfirmed candidate and release
its reservation. A subsequent confirmation returns 403 without activation.
The endpoint has CSRF enabled and uses a currently scoped independent Passkey
Step-Up fixture on a Secret-established session. This test does not prove that
Step-Up establishment itself; other integration tests cover that boundary.

At that point the HTTP rescue invoked the manual invalidator with the reason
`flow_canceled`. A regression expecting the existing `payload_unavailable`
reason failed: seed 23261, 1 run, 7 assertions, one failure. The invalidator now
has an explicit payload-failure entry point sharing the existing ownership,
session, Step-Up, retention and transaction guards. Source cancellation
validation recognizes this already-defined reason; no column, event name,
serialized field, reason enum or database constraint changed.

After correction the focused HTTP test passed with seed 42103, 1 run,
26 assertions, zero failures, errors or skips, in 1.423392 seconds.
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/operations/client_secret_manual_issuance_invalidator_test.rb test/models/client_secret_issuance_test.rb test/operations/client_secret_presentation_issuer_test.rb`
passed with seed 13694, 22 runs, 321 assertions, zero failures, errors or skips,
in 1.227664 seconds. These tests retain ordinary cancellation's original reason
and verify payload retirement denies a session that lost its scoped Step-Up.
RuboCop passed for the invalidator, issuance model, presentation controller
and invalidator test after fixing three line-length offenses. `git diff --check`
passed. Results were recorded on 2026-10-05 at 16:02 UTC.

File-wide RuboCop for the HTTP journey test failed with twelve offenses,
including the existing long journey's 69 assertions against the 30-assertion
limit. The new test's single long header line was corrected. Other existing
long lines and that assertion-count offense remain; this file-wide check is
not reported as passing. The focused HTTP test passed independently of lint.

An additional real MessageEncryptor fixture gives the prepared candidate payload
an already-expired encrypted envelope while its issuance remains within the
authorization deadline. Presentation and confirmation reject it, do not add
candidates or events, and the raw candidate remains unusable for sign-in.
The presentation file then passed with seed 8901, 5 runs, 68 assertions,
zero failures, errors or skips, in 1.037194 seconds.
RuboCop passed after correcting the fixture's multiline argument formatting and
using `1.second.ago` for its expired envelope. No application code was changed
for this expiry test.

Source inspection initially found signup's generic 403 handler without retirement.
An actual telephone signup/verified-contact/WebAuthn registration journey then
reproduced the missing cancellation fact. The focused regression first failed
with seed 14553 (1 run, 24 assertions, expected 410 versus 403), then was reordered
to check persistent behavior before status. Seed 11646 failed on the absent
cancellation fact (1 run, 27 assertions). No expected status was weakened.

The existing invalidator now exposes a signup payload-failure operation that uses
the established signup delivery authority and the same Source retirement mutation.
The signup controller invokes it only after a PayloadUnavailable exception.
The endpoint now returns 410 for retired unavailable payloads; invalid authority
still uses 403. No field, event, enum or database schema changed.

`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/integration/app_secret_signup_journey_test.rb --include '/handles payload_unavailable/'`
passed with seed 36737, 1 run, 34 assertions, no failures/errors/skips,
1.490482 seconds. It verifies candidate discard, reserve release, original
Passkey preservation, uncleared registration requirement, unchanged incomplete
Client status, payload-specific audit reason and rejection of subsequent save
confirmation.

The related command with signup journey, Passkey reservation issuer and manual
issuance invalidator files passed with seed 28534: 36 runs, 1489 assertions,
no failures/errors/skips, 10.765861 seconds. This includes signup A=0..20 and
cancellation/expiry outcomes, plus wrong-nonce payload retirement denial.
Results recorded on 2026-10-05 at 16:09 UTC. Explicit continuation into a new
delivery attempt remains unfinished; the existing canceled allocation cannot
silently generate another batch.
The signup test now restores its two explicit lifetime settings in teardown.
After that isolation correction the focused failure journey passed again with
seed 36326, 1 run, 34 assertions, no failures, errors or skips, 1.423031 seconds. RuboCop passed
for the invalidator, signup controller and Passkey reservation test; the signup
journey's existing file-wide lint issues were not represented as passing.

This verifies public operations and Base and signup HTTP against real persistence.
It does not prove browser behavior. A real-job manual payload-failure recovery test also
passed: `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test test/jobs/client_secret_audit_delivery_job_test.rb --include '/payload failure/'`,
seed 42399, 1 run, 8 assertions, no failures/errors/skips, 0.812475 seconds.
The public credential purger refuses deletion before Chronicle delivery. The
actual lifecycle job then delivers terminal facts and deletes the discarded
candidate and allocation. The surviving purged outbox reaches Chronicle through
the actual delivery job, and a repeated delivery creates no duplicate records.
The isolated fixture explicitly uses a microsecond purge delay while the job's
configuration uses the accepted lifetime values; no operational default changes.
RuboCop for the delivery job test passed after correcting numeric separators
and the teardown's long configuration-key list. `git diff --check` passed.
This recovery test delivers the full bounded batch; it does not prove partial
delivery of allocation versus individual candidate terminal audits is safe.

E2E and the
full suite were excluded by the user's instructions. The separate confirmed
manual POST replay regression remains unresolved pending shape approval.
