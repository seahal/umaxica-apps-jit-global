# Credential response nondisclosure

Status: closed

Authority: user requested remediation on 2026-10-22 and explicitly accepted equal-sized
recovery/withdrawal session payloads and discoverable-required Org registration. Existing
non-discoverable Org credentials need re-registration for Emergency Access. Deployment and
credential deletion are outside this local change.

## Scope

Close the reviewed Secret rate-limit, Emergency descriptor, invitation error, re-entry cookie
length and Passkey refusal disclosure paths. Preserve browser admission, CSRF, surface and actor
binding, verification, replay protection and existing issuance owners. Invitation requests retain
the common surface rate limit by explicit user decision; dedicated limits are deferred.

## Acceptance

- AC-1: Known and unknown Secret identifiers use the same identifier-derived attempt partition;
  distributed incorrect attempts reach the same refusal at the limit.
- AC-2: Emergency options expose no real credential descriptors, preserve selected-Operator
  binding, and accept only valid assertions for that Operator. Org registration requires
  discoverable credentials. Existing normal Entra-bound credential assertions retain their path.
- AC-3: While invitation provisioning is closed for Bureau migration, all submitted invitation
  states receive the same refusal, without consumption or provisioning.
- AC-4: Recovery and withdrawal real/dummy session payloads have equal serialized size and
  common full-operation response floors; dummy state never grants authority. Preserve expiry,
  supersession and successful proof cleanup.
- AC-5: Missing, inactive and incorrectly signed Passkey assertions receive one generic
  credential refusal with a full verification response floor. Protocol/admission failures remain
  explicit and do not authorize callers.
- AC-6: Preference DBSC advertisements name a real endpoint on the same host. Unsupported
  Auth/Base families emit no advertisement; Core app/com/org advertise their canonical route.

## Execution and verification

Implement each boundary with public request regressions, run focused tests and affected invariants,
and update current security documentation and the authentication checklist. Record actual results
against HEAD plus the pre-existing dirty worktree in evidence. Timing floors mitigate ordinary
latency differences; deployment timing distributions and delivery-provider behavior require
separate controlled operational verification and are not claimed by unit tests.

The prior Org descriptor documentation incorrectly treated random padding as anonymity. This
change supersedes that behavior with explicit user approval; no stored credentials are removed.

## Verification disposition

The focused suite covers the six criteria; executed results are recorded in
`evidence/2026-10-22-credential-response-nondisclosure-Q8N4.md`. An initial Base finalization
failure (`400` instead of `303`) also reproduced with the original two Passkey ceremony
implementations and the DBSC prerequisite fix retained. Its missing `OpOrgProtocolEpoch` domain
prerequisite is now explicit in that success test; the public Auth-to-Base happy path then passed.
No production authority rule or global test setup was relaxed.

Final scoped verification: 159 runs, 1126 assertions, no failures, errors or skips. Durable behavior
is owned by `adr/credential-response-nondisclosure.md`, the updated WebAuthn/DBSC security docs
and authentication checklist AUTH-27 through AUTH-30. Production latency distributions and
credential rollout readiness are explicitly outside local acceptance.

No persistent state axis or transition changed: OTP issuance, cancellation, verification and
session issuance remain with their existing owners. Session payload padding and challenge actor
encoding change browser transport only. No database migration or credential deletion was run.
