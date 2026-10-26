# WU-30: one-time Step-Up consumption

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree was already heavily modified by
this cycle and concurrent work; it had 873 porcelain entries during the final checks. No staging,
commit, migration, or database reset was performed.

## Mutation coverage

| Mutation | Result | Implementation and coverage |
| --- | --- | --- |
| APP Secret issuance chain | Wired once at terminal storage confirmation. Reservations, presentation, reattempt and invalidation retain evidence; sign-up Passkey registration is not charged twice. | `ClientSecretStorageConfirmationCommitter`; reservation/presentation/reattempt/invalidator tests in the 291-test focused set. Confirmation, concurrency and completed-issuance purger tests: 21 runs, 325 assertions, 0 failures/errors. |
| COM/ORG Secret create, update and destroy | Wired. ORG destroy uses the existing `CredentialSecurityTransition`; COM management uses the existing consumer and D-167 path. The legacy COM removal endpoint was missing that transition, so it now wraps deletion and Step-Up revocation in the credential transaction. | `OperatorSecretCredentialsUpdate`, `OperatorSecretCredentialsDestroy`, COM secret controller and `Base::Com::Identity::RemovalsController#create`. Secret service/controller coverage is in the 291-test focused set; COM removal and rename boundary tests after the final fix: 9 runs, 49 assertions, 0 failures/errors. |
| Revoke other sessions (APP/COM/ORG) | Wired only when another root session is actually revoked; a no-op retains evidence. | `AuthenticationOtherSessionsRevoker`; operation test in the 291-test focused set. |
| APP TOTP enrollment and rename | Wired after successful non-bootstrap enrollment and after an actual name change. Bootstrap and unchanged-name operations do not consume. | `IdentityTotpEnrollmentFinalCommitter`, `IdentityTotpNameCommitter`; operation tests in the 291-test focused set. The separate TOTP registration HTTP command had 67 runs, 1 failure and 5 errors, all in `totp_registration_boundary_test.rb` at the Auth setup route/CSRF/region redirect boundary. |
| Social link/unlink | Wired after a successful link or actual unlink; refusals and no-op unlink retain evidence. | Social link and unlink committers; link/unlink operation and integration coverage in the 291-test focused set. |
| ORG enforcement cases and appeals | Wired in the successful state transaction for interactive mutations. Background expiry/reconciliation and repeated terminal operations do not consume a new proof. | Enforcement case/appeal writers and controller tests in the 291-test focused set. |
| APP/ORG Avatar ownership transfer | Wired at successful request, accept and cancel mutations; idempotent replays do not spend the proof again. | APP/ORG transfer writers and registry-backed transfer paths; operation/controller tests in the 291-test focused set. |
| Base Step-Up admission and ORG relays | Admissions and page relays do not consume. The authorized downstream mutation consumes exactly once. | Existing admission issuer/relay paths; admission tests were included in the focused test work. |
| APP email preference | Wired only when the preference changes. | `IdentityEmailPreferenceCommitter`; operation test in the 291-test focused set. |
| COM/ORG email and telephone change/removal | Existing credential removal and finalization paths already call `CredentialSecurityTransition`, which clears Step-Up evidence on the actor's tokens; no second consumption was added. | Contact finalizers/removal paths; operation and controller coverage in the 291-test focused set. |

The general focused WU-30 set passed before the additional COM removal endpoint was found: 291 runs,
2,710 assertions, 0 failures/errors. The COM removal and rename tests above passed after that final
code change. The later broad run also exercised the changed Base controllers and operations.

## Binding and transaction limits

Consumption uses the existing `TokenStatusManagement#consume_step_up_evidence!` primitive in the
successful mutation transaction. Evidence is bound to actor, session, operation scope, purpose,
audience and the existing security-mode window. Current settings requirements pass `resource_ref: nil`,
so binding to an individual record remains deferred. A target-state database and a root-token database
do not share a distributed transaction; if the token database fails after a committed target write,
the target mutation may succeed while the proof remains usable. Per-record binding and cross-database
atomicity remain follow-up work. No migration was added.

The COM removal path's status transition is recorded under
`idp-visitor-secret-credential:T005` in `docs/mermaid/idp-state-machine-transition-inventory.md` and
`docs/mermaid/idp-state-machine-storage-overview.mmd`.

## Verification

- Final COM removal and rename regression tests: `bin/rails test test/controllers/base/identity_credential_management_test.rb test/integration/sign/com/credential_removal_constraints_test.rb` — 9 runs, 49 assertions, 0 failures/errors/skips.
- Final RuboCop for the additional COM controller and the two changed test files — 3 files inspected, no offenses. The preceding WU-30 candidate pass inspected 75 Ruby files with no offenses.
- Required broad command: `bin/rails test test/controllers/base test/operations test/models/concerns` — 2,732 runs, 22,014 assertions, 27 failures, 1 error, 0 skips. Failures include the concurrent region-parameter/default redirect and host allowlist changes, dashboard response expectations, and sign-out authority tests. One Step-Up-intent test also redirected to the passive Sign route instead of its expected 303, consistent with the same region-routing changes. The single error was a social authentication integration test receiving an unexpected nil response node. These broad failures were outside the WU-30 mutation consumer paths; the focused COM regression test passed after the final change.
- The separate TOTP registration HTTP command: 67 runs, 1 failure and 5 errors; all six came from Auth setup route/CSRF/region redirect expectations in `test/integration/totp_registration_boundary_test.rb`. TOTP enrollment/name operation tests passed in the focused set.
- A prior targeted WU-30 RuboCop pass inspected 75 files with no offenses; after the final COM endpoint/test additions, RuboCop inspected those 3 additional Ruby files with no offenses.
- `git diff HEAD --check` reports only the pre-existing unrelated trailing blank lines in `db/op_base_app_structure.sql` and `db/op_base_com_structure.sql`; those files were not changed here.
