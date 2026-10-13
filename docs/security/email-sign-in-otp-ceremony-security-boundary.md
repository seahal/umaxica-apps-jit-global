# APP/COM Email Sign-In OTP Ceremony Security Boundary

Documented date supplied: **2026-10-12**. Status: historical source inventory plus the accepted
security contract. The historical snapshot and the current local implementation are separate
records; this document is not an acceptance result. The supplied date is metadata, not a
verification timestamp.

Decision authority: [ceremony binding and risk acceptance ADR](../../adr/email-sign-in-otp-ceremony-binding-and-risk-acceptance.md).
Broader OTP inventory: [OTP audit](otp-audit.md). This document does not replace either record or
change the existing Email OTP product exception.

## Source and verification limits

The supplied inspection used public feature snapshot
`6fa6867d44b5499632079775cb0fb22cbfddd339`, potentially older than the local tree. The observations
below concern that snapshot, not exact production behavior or current local-code conformity.
No Rails, HTTP or concurrency tests were executed by this documentation capture.

The existing [local source inventory](email-otp-ceremony-security-boundary.md) describes later
ceremony-specific challenges, resend SID-purpose binding, removal of `CommonOtp`, and retained
`already_verified` evidence. Those findings are preserved. Consequently, the historical
credential-scoped premise below MUST NOT be used as a current local-code finding. Local feature
HEAD must be re-inspected before implementation or conformance reporting.

## Current local implementation boundary

The current checkout no longer uses the snapshot's identifier-owned `CommonOtp`/`OtpLockable`
proof path for Email or Telephone ceremony verification. The active ceremony-owned path stores a
keyed verifier and generation on the concrete surface-local ceremony transaction, binds the proof
to the actor, session, purpose, candidate and expiry, and consumes it under the transaction lock.
`EmailOtpPolicy` and `TelephoneOtpPolicy` remain independent identifier-channel policies for
failure budgets, cooldown and issuance timing; they do not own ceremony proof or share a stateful
OTP concern. Authentication Email OTP is a separate admitted-session challenge implemented by
`AuthEmailOtpChallenge`, with its own parent/session/contact binding and one-shot result window.
Step-Up Email OTP remains a separate Step-Up transaction contract.

The current code rejects retired identifier-owned proof fields and does not reconstruct a valid
OTP from an identifier row. New ceremony proof uses the realm/channel verifier key and the
existing encrypted delivery boundary. The exact route/provider applicability matrix, live
external delivery, provider observability and independent acceptance remain separate verification
work; this paragraph does not claim those checks passed.

## OTP entrypoint inventory in the supplied snapshot

| Surface | Sign-Up Email | Sign-Up Telephone | Sign-In Email | Step-Up Email |
| --- | --- | --- | --- | --- |
| APP | `Auth::App::Sign::Up::Check::Email::OtpsController` | `Auth::App::Sign::Up::Check::Telephone::OtpsController` | `Auth::App::Sign::In::EmailsController` | `Auth::App::Verification::EmailsController` |
| COM | `Auth::Com::Sign::Up::Check::Email::OtpsController` | `Auth::Com::Sign::Up::Check::Telephone::OtpsController` | `Auth::Com::Sign::In::EmailsController` | `Auth::Com::Verification::EmailsController` |

These are eight surface/purpose/channel families. Telephone is Sign-Up contact confirmation only.
The new target covers the two Email Sign-In families; preserve existing Sign-Up/Step-Up models.

## Historical Auth/Base boundary observations

1. Base alone owns Browser Sessions, OIDC and RP-session authority. Auth performs credential
   ceremonies and records authentication evidence.
2. Protected sign-in paths call `require_sign_in_ceremony_admission!`. `AuthCeremonyContext`
   resolves an admitted active server-side ceremony from its cookie; email/OTP input alone cannot
   bypass admission.
3. `AuthCeremonySidCookie` uses random opaque `__Host-auth_sid` in secure environments: HttpOnly,
   Secure, host-only, SameSite=Lax, Path=/. `AuthCeremonySession` stores a 32-byte random SID's
   digest, with a default 30-minute lifetime. This cookie carries continuity, not login authority.
4. Rails separately uses encrypted/signed cookie-backed state (`__Host-session` in secure
   environments). The two cookies have distinct semantics; neither alone proves OTP issuance
   association.
5. Successful local verification enters the existing Auth/Base evidence handoff, not an
   Auth-issued Base Browser Session.

## Historical OTP lifecycle observations by purpose

### Sign-Up Email and Telephone

The supplied snapshot describes `SignOtpCeremony` binding contact confirmation to a surface-local
Sign-Up flow, pending contact type/record, expected destination and supplied flow public ID.
Issuance/verification use a row lock and verification clears the OTP. `SignUpStepGate` checks the
current flow, signed flow binding and state-machine phase. These four entries are distinct from
the Sign-In target. Later local ownership is described in the retained local inventory.

### Sign-In Email

The supplied snapshot describes `CommonOtp` generating six-digit HOTP using SecureRandom/ROTP,
with secret and counter on surface-local `ClientEmail`/`VisitorEmail` records and a ten-minute
`CommonOtpPolicy::AUTHENTICATION_TTL`. `verify_otp_code_and_consume` verifies and clears under one
record lock. The snapshot's `OtpLockable` sentence is historical source evidence only; it is not
the current local implementation or a recommendation to restore that path.

APP records the email ID through `SignAppInEmailAuthenticationState`; COM uses Rails Session keys.
Both require ceremony admission. The supplied inspection did not visibly find an issuance-to-
ceremony comparison: another admitted ceremony for the same email could potentially reach the
credential-scoped value. This is a code-reading first-use exposure, not confirmed HTTP exploitation
or evidence of reuse after locked consumption. Later local code uses different challenge storage.

Historical `SignInOtpResendState` contains kind, target and surface with encrypted finite-lifetime
state, without originating ceremony. `SignInOtpResender` replaces credential-level codes and
enforces send budgets. Future review must include resend, replacement and another ceremony's
possible invalidation of an earlier code; it must also account for later local SID-purpose binding.

### Step-Up Email

`IdentityStepUpEmailCodeIssuer` and `IdentityStepUpEmailVerificationCommitter` use the authenticated
surface-local actor, credential, session token, transaction and Step-Up Session.
`StepUpEmailChallenge` retains generation, transaction-bound digest, delivery state, expiry and
`email_code_consumed_at`. Verification consumes the generation and records `email_otp` with
achieved AAL `none`. This is neither NIST AAL2 nor phishing-resistant proof for stronger operations.

## Accepted target behavior — not verified by this change

1. Persist a server-verifiable issuance/generation association with registered credential, surface,
   specific admitted Auth Ceremony and appropriate Rails continuity.
2. Require matching issuance and verification ceremonies; correct six-digit input alone is
   insufficient. Refuse A's code in B even for the same credential.
3. Preserve exactly one consumption under concurrency/retry, authoritative locking and finite TTL.
4. Replacement invalidates the previous generation; reset, restart, rotation and cancellation
   cannot revive or transfer it.
5. Require current authorized ceremony for resend; an encrypted token alone is insufficient.
   Preserve failed-attempt budgets.
6. Fail closed before evidence or Base sessions. Keep cookies, OTPs, issuance references and
   binding secrets out of email, query parameters, Inertia props and logs; avoid enumeration.
7. Preserve Auth/Base handoff authority and APP/COM data isolation; introduce no token authority.

Binding owner, independent Rails nonce, admission/rotation continuity, credential-global versus
per-ceremony active-code policy and cross-database consistency remain TBC. Existing controls are
not completion evidence for the full target contract.

## Threat cases and disposition

| Case | Historical exposure/control or limitation | Approved disposition |
| --- | --- | --- |
| A issues X; admitted B uses X first | Supplied snapshot verifies credential-scoped OTPs | Not accepted; require cross-ceremony refusal. Local challenge findings must be reconciled. |
| Same correct code submitted twice/racing | Historical verification/consumption share a row lock | Not accepted; preserve and test atomic one-time consumption. |
| Another ceremony's resend replaces A's code | Historical credential-level replacement and resend state | Active-code/concurrency policy TBC. |
| Necessary Auth/Rails bearer secrets and valid OTP stolen | Bearer possession can impersonate continuity | AR-OTP-001, bounded to this cycle. |
| B starts its own ceremony and steals B's code from compromised mailbox | B is the actual issuing ceremony | AR-OTP-002; mailbox trust dependency. |
| User deceived into disclosing B's code without mailbox compromise | Manual Email OTP is not phishing resistant | Acceptance TBC; outside AR-OTP-002. |
| UMAXICA leaks OTPs/cookies/challenge secrets | Application-controlled disclosure | Not accepted; preserve secrecy and audit controls. |

Acceptance of bearer-secret theft and mailbox compromise demonstrates no attack; it concerns
adversaries obtaining the stated prerequisite secrets. Risk owner, likelihood, impact, next review
date and expiry remain TBC in the ADR.

## Future evidence and standards

The [backlog](../../plans/backlog/email-sign-in-otp-ceremony-binding.md#supplemental-regression-catalog)
records isolated-browser issuance/denial/success, races, stale/canceled/rotated continuity,
replacement, resend, delivery constraints and Base refusal tests. None ran for this capture.

The existing [OTP audit](otp-audit.md) records product exceptions and hardening, not proof of this
association. The ADR retains official-source analysis: OWASP guidance covers single-use, finite
expiry, attempt limits and phishing-resistant alternatives; NIST SP 800-63B-4 disallows email as
qualifying out-of-band authentication, distinct from signup address confirmation. This target
does not confer MFA, NIST AAL2, phishing resistance or full standards conformance. ASVS review
reference version is 5.0.0; this capture adds no unverified requirement numbers.

Supplied references:

- [OWASP ASVS](https://owasp.org/projects/asvs)
- [OWASP MFA Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html)
- [NIST SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)

## Historical source path inventory

These are references in the supplied public-snapshot inspection, not assertions of current file
existence. Brace notation denotes APP/COM alternatives.

- `app/controllers/concerns/auth_ceremony_context.rb`, `auth_ceremony_sid_cookie.rb`;
  `app/models/concerns/auth_ceremony_session.rb`
- `config/initializers/session_store.rb`; `lib/jit_session_cookie_config.rb`
- `app/controllers/concerns/common_otp.rb`; `app/models/concerns/otp_lockable.rb`;
  `app/values/common_otp_policy.rb` (historical snapshot paths; verify current existence before
  treating them as runtime sources)
- `app/controllers/auth/{app,com}/sign/in/emails_controller.rb`
- `app/services/sign_app_in_email_authentication_state.rb`, `sign_in_otp_resend_state.rb`,
  `sign_in_otp_resender.rb`
- `app/controllers/auth/{app,com}/sign/up/check/{email,telephone}/otps_controller.rb`;
  `app/services/sign_otp_ceremony.rb`
- `app/controllers/auth/{app,com}/verification/emails_controller.rb`;
  `app/operations/identity_step_up_email_code_issuer.rb`,
  `identity_step_up_email_verification_committer.rb`;
  `app/models/concerns/step_up_email_challenge.rb`

Local development HEAD remains authoritative for later implementation inventory.
