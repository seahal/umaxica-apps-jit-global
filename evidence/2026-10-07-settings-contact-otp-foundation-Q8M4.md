# Authenticated Contact OTP foundation

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- The worktree contains inherited and current uncommitted changes affecting these results.
- Scope: manifest-verified `20261007fresh3` disposable test databases only; shared and production databases were not accessed.
- The owner approved the fifteen-field `credential_registration_otp_context`, registration-specific delivery metadata and limited SQL proof guards. Auth/signup proof formats remain separate.

## Observed checks

- `bin/rails test test/integration/contact_settings_otp_atomic_commit_test.rb test/controllers/base/com/identity/telephones/registrations_controller_test.rb`: 21 runs, 200 assertions, four failures, no errors or skips. All four real APP/COM email/telephone journeys reproduce OTP consumption before a failed binding write; those regressions are unresolved. The seventeen COM telephone controller cases passed after aligning their request fixtures with the published `visitor_telephone` form scope.
- Earlier fixture/runtime failures were missing COM verification entry translations, the receiver/form scope mismatch and fixture-only unsupported COM confirmation fields. Four locale bundles now contain the exact COM keys; no locale fallback or parameter compatibility path was added.
- `bin/rails generate migration` generated four new APP/COM Source migrations using the owning `app_zenith` and `com_zenith` database aliases. `bin/rails db:migrate` exited zero in the verified test fleet. Nullable columns, exact shape checks, finite UTC timestamps and verified-proof immutability triggers were added; no existing Contact or proof facts were backfilled. Existing migrations were not changed.
- `bin/rails test test/lib/credential_registration_otp_code_digest_test.rb`: RED before implementation (two runs, one assertion, one failure, one error); GREEN after implementation (two runs, thirty assertions, no failures/errors/skips).
- `bin/rails test test/operations/contact_registration_otp_issuer_test.rb`: RED before implementation (four runs, four missing-class errors).
- `bin/rails test test/operations/contact_registration_otp_issuer_test.rb test/lib/credential_registration_otp_code_digest_test.rb`: six runs, 98 assertions, no failures/errors/skips. Issuance snapshots the original existing Contact ceremony UUID, Base browser digest, current root, owner, candidate, destination, counter and bounded OTP deadline. Code material is represented only by the registration-specific keyed digest.

The registration-specific verification operation was subsequently tested through the public issuer
and actual HOTP: 68 RED missing-class errors before implementation; then
`bin/rails test test/operations/contact_registration_otp_verification_committer_test.rb test/operations/contact_registration_otp_issuer_test.rb test/lib/credential_registration_otp_code_digest_test.rb`
passed with 74 runs, 526 assertions and no failures/errors/skips, including after the responsibility-preserving
predicate split. The matrix covers exact proof retry, wrong code, foreign browser/owner/root/candidate/Ticket,
release, root revocation, shared and candidate budget exhaustion, and both deadlines immediately before,
at and after the boundary with explicit owning DB clocks. No HTTP caller or binding finalization is inferred
from the operation-only result.

- `bin/rails test test/values/contact_registration_otp_delivery_binding_value_test.rb test/values/sign_up_otp_delivery_binding_value_test.rb test/values/auth_email_otp_delivery_binding_value_test.rb`: 21 runs, 267 assertions, no failures/errors/skips, after nine registration binding tests first reproduced the missing implementation.
- `bin/rails test test/operations/contact_registration_otp_delivery_issuer_test.rb test/operations/contact_registration_otp_verification_committer_test.rb test/operations/contact_registration_otp_issuer_test.rb test/values/contact_registration_otp_delivery_binding_value_test.rb`: 149 runs, 1,317 assertions, no failures/errors/skips. The delivery operation was RED first (68 missing-class failures) and refuses stale generation, wrong destination/code, verified or cleared OTP, released/finalized Contact, revoked root/device, expired/consumed Ticket, missing context and foreign Contact/Ticket. Transport and all protected facts are preserved. Actual concurrent lock retention is not certified by this matrix.
- `bin/rails test test/services/outbound_sensitive_payload_test.rb test/values/contact_registration_otp_delivery_binding_value_test.rb test/values/sign_up_otp_delivery_binding_value_test.rb test/operations/contact_registration_otp_delivery_issuer_test.rb`: 87 runs, 889 assertions, no failures/errors/skips. Registration SMS version-two roundtrip was RED before adding explicit registration-purpose tuple validation. Unsupported purposes and malformed tuples remain refused; unbound version-one SMS behavior is unchanged.
- `bin/rails test test/controllers/base/com/identity/telephones/registrations_controller_test.rb`: 18 runs, 76 assertions, no failures/errors/skips, including explicit refusal of the unpublished legacy parameter scope.
- Scoped RuboCop checks passed for the new issuer, verifier, keyed digest, delivery binding value, their tests and the four generated migrations. The delivery operation's initial formatting offense was subsequently corrected; its final scoped lint has not yet been rerun in this record.

The actual Mailer/SMS adapter-to-worker matrix was then reproduced RED (36 runs, 126 assertions,
18 missing-email-metadata errors and 18 unbound-SMS-envelope failures). After wiring the approved
metadata and final delivery operation, correcting MIME decoding in the fixture and adding both
existing localized SMS cases,
`bin/rails test test/integration/contact_registration_otp_transport_binding_test.rb test/integration/signup_otp_delayed_transport_test.rb test/jobs/outbound/sms_delivery_job_test.rb`
passed with 69 runs, 633 assertions and no failures/errors/skips. Registration SMS validates the
decrypted body against the two existing supported message templates and the original Source HOTP;
it does not guess a code or reconstruct legacy bindings.

`bin/rails test test/notifiers/notify/otp_notifiers_test.rb test/adapters/otp_email_notifier_adapter_test.rb test/adapters/signup_otp_delivery_payload_test.rb test/operations/contact_registration_otp_delivery_issuer_test.rb test/integration/contact_registration_otp_transport_binding_test.rb`
first found one stale enqueue-class assertion (126 runs, 1,262 assertions, one failure): the actual
registered credential-safe subclass is `OtpNotifierEmailDeliveryJob`, not the superclass excluded
by the test's exact `only:` filter. The assertion still requires exactly one job of the registered
class. The complete five-file matrix then passed with 126 runs, 1,262 assertions and no failures/errors/skips.
Registration-specific Noticed execution was subsequently exercised through its actual queued job,
params callback and mailer. The first fixtures incorrectly treated serialized symbols as strings
and then deserialized keyword keys as string keys; both fixture errors were corrected with public
`ActiveJob::Arguments.deserialize`, without bypassing the job. The ten APP/COM current, verified,
reissued, root-revoked and expired-Ticket cases passed with 212 assertions and no failures/errors/skips.

`bin/rails test test/models/credential_registration_otp_proof_database_test.rb test/integration/contact_registration_otp_noticed_transport_test.rb`
passed with 14 runs, 592 assertions and no failures/errors/skips. Direct writes were rejected for
malformed shapes, missing/extra fields, invalid realm/purpose/UUID/ref/digests/counter/time facts,
unpaired result timestamps and deadlines beyond sixty seconds. Canonical unsigned counter endpoints,
reference lengths, digest length and microsecond result-deadline neighbors were exercised; valid
boundary probes were rolled back. All four Source models rejected clearing or replacing an actual
publicly verified proof. OTP stayed consumed and the original Contact Ticket stayed pending.

The four Contact Action Policies now expose their complete operation-specific requirement rather
than copying ownership permission into a freshness decision. The existing method set, fifteen-minute
freshness, explicit property booleans, purpose, audience and nil resource/tenant contract are preserved;
the requirement binds the exact Source owner and server-resolved root. Four tests first reproduced the
missing policy interface. `bin/rails test test/policies/contact_registration_requirement_test.rb test/policies/client_email_policy_test.rb test/policies/client_telephone_policy_test.rb test/policies/visitor_email_policy_test.rb test/policies/visitor_telephone_policy_test.rb`
then passed with 52 runs, 184 assertions and no failures/errors/skips. Foreign/missing roots and owners
are refused. Controller and finalizer adoption are not inferred from this policy-only result.

The original 56-case real-signed-Passkey finalizer matrix passed with 812 assertions after correcting
credential retention checks and the early Root revocation CHECK collision. Source failure rolls back
replacement and its audit intents while preserving verified proof; Ticket receipt failure leaves Source
facts committed and the original Ticket pending. Exact original retries reconcile those facts without
another Source mutation or duplicate audit. A later twelve-case Root-clock boundary matrix reproduced
eight at/after-expiry failures; rechecking after previous-binding and credential locks fixed them.
`bin/rails test test/operations/contact_registration_otp_finalizer_test.rb test/models/contact_registration_receipt_test.rb test/models/step_up_session_revocation_test.rb`
then passed with 116 runs, 1,396 assertions and no failures/errors/skips. The receipt writer owns its
clock and UUID, rejects caller-supplied receipt facts, and has precise expiry boundary tests.

The broader six-file Root/challenge/credential-transition check returned 145 runs, 1,705 assertions,
two failures and four errors. One regression introduced by the new Session writer was six locked-lookup
SELECTs instead of the existing three; moving lookup and locking into the named writer fixed it.
The targeted Root/finalizer/query matrix passed with 81 runs, 1,137 assertions. Other inherited Goal
failures remain: omitted mandatory StepUpRequirement properties, removed SignInFlow.step and OIDC APIs,
and local-continuity expiry behavior. They are not certified as a passing historical baseline. The
Passkey challenge fixture was subsequently migrated from a custom issuance helper to the real public
issuer and explicit complete requirement; its three tests passed with 22 assertions.

`bin/rails test test/integration/contact_registration_otp_delivery_lock_test.rb` passed with four runs,
84 assertions and no failures/errors/skips. Independent PostgreSQL backend PIDs, queue barriers and
NOWAIT row locks show that Source owner/Contact and Ticket device/root/original flow locks remain held
through transport. Reissue/revoke cannot acquire them until transport releases; protected facts remain
unchanged, and old generation delivery is refused after reissue and revocation.

The actual signed-Passkey HTTP Source-fault/retry tests for APP telephone, COM telephone and APP email
each passed with one run, 51 assertions and no failures/errors/skips after caller wiring. The tests now
require the approved consumed-OTP/immutable-proof contract, exact original pending Ticket after Source
failure, fixed separate result deadline and original consumed Ticket after identical retry. APP's
latest-pending-email adoption was removed. The concrete Base caller supplies its own fixed product-axis
snapshot; the generic ActorSupport currently leaves that axis unknown, which is not accepted by the
finalizer. No Auth/signup proof is reused for settings.

After COM email caller wiring, `bin/rails test test/integration/contact_settings_otp_atomic_commit_test.rb`
passed with four runs, 204 assertions and no failures/errors/skips. All four surfaces/channels now
preserve the bounded immutable proof and original pending Ticket across Source binding failure,
then finalize the same candidate on identical HTTP retry. Scoped RuboCop passed for the eleven
changed controller/concern/finalizer/test files; no comprehensive lint claim is inferred.

The public resend issuer matrix passed with 74 runs and 890 assertions. The existing email cooldown
is thirty seconds; immediately neighboring microseconds were tested without changing that contract.
Actual signed-Passkey APP email HTTP resend initially failed three of four cases. After bound resend
wiring, `bin/rails test test/integration/contact_registration_otp_http_resend_test.rb` passed with
four runs, 179 assertions and no failures/errors/skips. It verifies unchanged original flow,
deadlines and budgets, stale queued delivery refusal, current delivery, and retained proof after
Source failure. No COM resend endpoint was introduced.

The combined settings Source-fault, actual HTTP resend and public resend issuer matrix passed:
`bin/rails test test/integration/contact_settings_otp_atomic_commit_test.rb test/integration/contact_registration_otp_http_resend_test.rb test/operations/contact_registration_otp_resend_issuer_test.rb`
reported 82 runs, 1,273 assertions and no failures/errors/skips. Scoped RuboCop inspected the five
changed resend/controller/concern files with no offenses.

Broader email controller checks initially reported 34 runs, six failures and one error. Four
assertions still named the candidate public ID rather than the canonical original ceremony UUID
as the audit operation; another expected physical deletion of a locked candidate, contrary to
retention. Those assertions now verify exact original operation provenance and retained locked
authority without successful verification or finalization. A real expiry defect was fixed:
unverified screen validity checked the stored challenge deadline but not the current OTP deadline.
The isolated COM expiry case passed with one run and three assertions; the eight actual settings
HTTP cases remained green with 383 assertions. The two broader controller files then reported
34 runs, 190 assertions, no failures and one remaining bootstrap error. That error remains open.

The APP/COM bootstrap public-operation matrix initially reported 28 runs, six failures and
22 errors because the finalizer did not accept the original bootstrap parent. The explicit
parent-bound path then passed together with the ordinary finalizer matrix: 96 runs, 1,614 assertions.
It checks original durable admission/browser/root binding, parent cancellation/expiry, changed
policy, Source and both Ticket receipt faults, exact recovery and replay. Bootstrap consumes its
original parent without writing Root freshness. The primary ten-minute window is checked only at
issuance, not again at completion. No storage shape changed for this path.

Actual APP setup and COM email controller tests plus settings Source-fault/retry and HTTP resend
passed with 33 runs and 604 assertions after explicit marker concern wiring. The COM fixture now
chooses email through an actual Setup POST rather than assuming unissued bootstrap permission.
After simplifying the predicates, the public bootstrap/ordinary finalizer and APP setup/COM email
controller matrix passed with 121 runs, 1,835 assertions and no failures/errors/skips. Actual HTTP
bootstrap receipt-fault recovery after committed Source binding is not yet certified.

The actual HTTP bootstrap receipt-fault matrix initially reproduced four freshness-gate refusals
(four runs, 140 assertions, four failures). A read-only original-proof/provenance predicate now
admits only pending receipt reconciliation through both existing verification gates; OTP input,
Turnstile/CSRF, policy, browser, Root and original parent are still checked. Wrong codes remain
422 and update only the existing candidate counter/window anchor. The expanded public/bootstrap
HTTP/permission-boundary/controller selection passed with 81 runs, 1,381 assertions and no
failures/errors/skips. The separate Contact/bootstrap model receipt boundary selection passed with
40 runs and 180 assertions, including expiry immediately below/at/above and caller-clock refusal.
Eight public operation probes also reproduced missing stored-return-target checks before those
checks were fixed; the subsequent 49-case bootstrap/HTTP/setup selection passed with 1,156 assertions.
Seven changed bootstrap files and five subsequent predicate/controller/test files passed scoped
RuboCop; no whole-worktree lint result is inferred.

A further cancellation/restart probe is genuinely RED:
`bin/rails test test/operations/contact_registration_otp_bootstrap_finalizer_test.rb` reported
38 runs, 868 assertions, two failures and no errors/skips. On both APP and COM, actual cancellation
of the original bootstrap followed by issuing another bootstrap on the same Root/browser allows
the old verified Contact challenge to finalize under the new parent. The Contact Ticket has no
persisted original-bootstrap association, so current Session/parent/browser checks cannot distinguish
this substitution. A nullable immutable parent FK and owner/Root binding constraint are proposed
for the two owning email Ticket tables, without changing approved Source JSON or delivery shape,
backfilling old authority or editing historical migrations. That new shape and limited SQL DDL
await explicit approval. The failing tests remain intact and Task 19.3 remains unchecked.

## Not certified

Settings bootstrap, cancellation and broader inherited regression repairs remain incomplete. Empty development construction, Final Verification, live providers and browser-only behavior were not run for this foundation. Legacy OTP job inspection and safe handling in shared/production environments remain rollout prerequisites, not inferred from the local migration result. No Task checkbox was completed by these foundation checks.
