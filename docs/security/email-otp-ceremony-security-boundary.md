# Email OTP Ceremony Security Boundary

## Evidence and scope

Read-only local source inspection on 2026-10-11 examined branch `feature`, HEAD
`65e2f0f750b6262da38eb9022f9bf71e47a3f3a2`. The worktree already contained unrelated application,
test and harness changes; none was modified by this task. This is source evidence from the current
local tree, not remote-repository, runtime, deployment or test-pass evidence. No authentication
tests were written or executed. The target contract is owned by the
[accepted ADR](../../adr/email-sign-in-otp-ceremony-binding-and-risk-acceptance.md).

The observations were re-inspected on 2026-10-11 against `feature` at HEAD
`a1ec83a7384a424c97671356268ec5c4ad8347d4`. `git diff --stat` between the two revisions reported no
change to the Auth controllers, controller concerns, services, model concerns, `app/lib`,
`app/values`, `config/routes/auth.rb` or the cited ADRs and security documents, and
`git status --short` reported no uncommitted change to the OTP sources cited below. The statements
in this document therefore hold for both revisions. These documentation files were uncommitted
during the re-inspection, and this task performed no commit.

## Current implementation

### Eight-route inventory

Routes are declared in [config/routes/auth.rb](../../config/routes/auth.rb). Paths below are
relative to each surface's Auth host; APP and COM remain separate trust boundaries. Entry,
verification and resend endpoints of a method are one route family, not additional families.

| Surface | Purpose | Channel | Route family | Existing binding owner |
| --- | --- | --- | --- | --- |
| APP | Sign-Up | Email | `/sign/up/email`, `/sign/up/check/email/otp` | Client Sign-Up flow/nonce and Email ceremony transaction |
| APP | Sign-Up | Telephone | `/sign/up/telephone`, `/sign/up/check/telephone/otp` | Client Sign-Up flow/nonce and Telephone ceremony transaction |
| APP | Sign-In | Email | `/sign/in/email`, `/web/v0/in/email/otp` resend | Client Auth Ceremony Session and parent |
| APP | Step-Up | Email | `/verification/emails`, member redelivery | Client Step-Up transaction/session |
| COM | Sign-Up | Email | `/sign/up/email`, `/sign/up/check/email/otp` | Visitor Sign-Up flow/nonce and Email ceremony transaction |
| COM | Sign-Up | Telephone | `/sign/up/telephone`, `/sign/up/check/telephone/otp` | Visitor Sign-Up flow/nonce and Telephone ceremony transaction |
| COM | Sign-In | Email | `/sign/in/email`, `/web/v0/in/email/otp` resend | Visitor Auth Ceremony Session and parent |
| COM | Step-Up | Email | `/verification/emails`, member redelivery | Visitor Step-Up transaction/session |

Telephone is Sign-Up only in this inventory. The accepted new requirement targets the two Email
Sign-In families; it does not redesign the other six families.

### Continuity and authority

[AuthCeremonySidCookie](../../app/controllers/concerns/auth_ceremony_sid_cookie.rb) writes an
HttpOnly, SameSite=Lax, Path=/ cookie with no Domain attribute. Secure and the `__Host-` prefix are
conditional on `JitSessionCookieConfig.force_secure?`; this inspection does not attest deployment
settings. [AuthCeremonySession](../../app/models/concerns/auth_ceremony_session.rb) generates 32
random bytes, stores their SHA-256 digest, and defaults to 30-minute continuity. Active lookup
rejects terminal or expired rows; admission, rotation, replacement, cancellation and completion
have server-side transitions.

[AuthCeremonyContext](../../app/controllers/concerns/auth_ceremony_context.rb) resolves the cookie
to an active surface-local row and requires admitted continuity and an appropriate parent/intent.
Its cleanup revokes continuity, clears cookies and calls `reset_session`. The
[admission concern](../../app/controllers/concerns/auth_ceremony_admission.rb) correlates the Auth
SID with the retained Base/Auth admission binding. Admission and cookie possession are not login
authority. The [Base/Auth ADR](../../adr/base-auth-ceremony-and-seven-rp-boundary.md) and
[current sign-in result contract](sign-in-sequence.md#current-rails-result-contract) retain Base
Browser Session, OIDC, RP Session and token authority with Base.

### Sign-In issuance, verification and consumption

The [APP](../../app/controllers/auth/app/sign/in/emails_controller.rb) and
[COM](../../app/controllers/auth/com/sign/in/emails_controller.rb) controllers issue and verify
through the admitted ceremony's
[AuthEmailOtpChallenge](../../app/models/concerns/auth_email_otp_challenge.rb). APP stores the
Contact ID or dummy address through
[SignAppInEmailAuthenticationState](../../app/services/sign_app_in_email_authentication_state.rb);
COM uses separate Rails Session ID/address entries. These are flow lookup state, not independent
Base credentials. Both loaders check that the ceremony challenge matches the Contact/dummy mode.

Issuance creates a six-digit CSPRNG code and UUID generation on `email_otp_context`. The context
includes surface, purpose, SID digest, parent kind/reference, original Contact/owner, destination
digest and finalized binding snapshot. The
[keyed code digest](../../app/lib/auth_email_otp_code_digest.rb) incorporates those fields and
generation. OTP expiry is capped by the ten-minute authentication policy and both ceremony and
parent deadlines. Dummy challenges do not deliver usable authentication evidence. Delivery carries
ceremony reference/generation metadata; the challenge exposes a locked delivery guard that checks
generation, binding, code and deadlines.

Verification checks input format, current scope, cancellation, original Contact binding, parent
state and deadlines. Parent, Auth continuity, owner and Contact locks serialize the comparison and
`verified_at` write. A successful fresh comparison records verified evidence with a result deadline
of at most 60 seconds, capped by parent/ceremony deadlines. Destination-scoped
`EmailOtpVerificationFailureBudget` and Contact failed attempts are separate controls; issuance
does not reset them. Replacement writes a new context/generation/digest, and reissue after
verification is refused.

There is a material retained-result distinction: while the retained result is live and the parent
remains eligible, `verify_email_otp!` can return `already_verified` before comparing another
well-formed submitted code. The
[result type](../../app/values/auth_email_otp_verification_result.rb) labels only `verified` as
fresh success, but both controllers accept `verified_evidence?` for continuation through
`AuthenticationSessionCommitter`. This is observable source behavior, not proof of a second OTP
consumption or second session issuance. Its compatibility with the newly recorded strict reuse
contract is **TBC**.

`app/controllers/concerns/common_otp.rb` is absent from the active tree, and no production
`CommonOtp#verify_otp_code_and_consume` call was found in `app/` or `lib/`. The
[race-condition ADR](../../adr/email-otp-race-condition-fixes.md) describes the earlier database
row-lock protection; the
[realm-separated identifier ADR](../../adr/realm-separated-identifiers-and-dead-history.md)
records removal of the unused helper. Copies under `tmp/` are excluded from implementation
evidence. Current challenge locking must be preserved rather than portraying the old protected
path as a demonstrated vulnerability.

### Resend authorization

[SignInOtpResendState](../../app/services/sign_in_otp_resend_state.rb) emits a version-2 AES-GCM
encrypted/authenticated envelope with a 30-minute TTL. Its purpose includes the server-supplied
admitted Auth SID digest. Payload fields include email kind, target, surface, real/dummy mode and
Contact/owner/finalized-binding snapshot. It has no explicit ceremony ID or OTP generation field.

The [APP endpoint](../../app/controllers/auth/app/web/v0/in/email/otps_controller.rb) and
[COM endpoint](../../app/controllers/auth/com/web/v0/in/email/otps_controller.rb) require ceremony
admission and pass that ceremony plus SID digest to
[SignInOtpResender](../../app/services/sign_in_otp_resender.rb). The resender checks surface/model,
SID agreement, encrypted purpose, Contact snapshot and current challenge, then issues through that
ceremony. Thus current state is tied to individual ceremony continuity through its SID digest,
not only email target and surface. Cooldown reservation uses an occurrence row lock; it does not
replace challenge authorization. Full rotation/restart/generation and concurrent behavior remains
unverified.

### Other OTP binding models

[EmailSignUpOtpIssuer](../../app/operations/email_sign_up_otp_issuer.rb) and the
[Email](../../app/operations/email_sign_up_otp_verification_committer.rb)/
[Telephone](../../app/operations/telephone_sign_up_otp_verification_committer.rb) Sign-Up verifiers
check the owning flow nonce and pending Contact/owner under locks. Transaction lookup derives a
session reference from the original flow public ID and nonce digest. Their retained proof handling
is separate from the Email Sign-In target.

APP/COM verification controllers use `IdentityStepUpEmailCodeIssuer` and
`IdentityStepUpEmailVerificationCommitter`. The
[StepUpEmailChallenge](../../app/models/concerns/step_up_email_challenge.rb) binds credential,
generation, transaction and session, checks delivery and expiry, and records consumption under
locks. It records `aal: "none"` and `phishing_resistant: false`. These observations do not certify
all routes or extend the accepted redesign scope.

## Accepted target behavior

The ADR requires originating-ceremony and corresponding browser-session continuity binding for
APP/COM Email Sign-In, fail-closed invalid binding, single consumption, superseded-code invalidation
without failure-budget reset, and equally strong resend authorization. The security proof must
connect issuance to admission, Auth row/cookie and Rails Session continuity; valid cookie presence
alone is insufficient. Binding secrets remain outside emails, URLs, browser-readable token storage
and logs. Auth stays ceremony-only and Base retains authority. These are accepted targets, not a
claim of current production conformity.

## Threat scenarios A and B

**A:** independent, admitted browser ceremonies A and B share an account/email. B obtains A's
unconsumed code and submits it with B's own valid continuity. The target requires refusal without
authentication evidence or session issuance. One-time consumption alone does not resolve first-use
theft. Cross-ceremony success has not been demonstrated in this task.

**B:** an adversary initiates legitimate B and reads B's code by compromising the external mailbox.
Binding alone cannot prevent use within B. This accepted limitation must not be presented as a
successful prevention test.

## Accepted residual risks

User-approved on 2026-10-11, with the ADR as the authoritative risk record:

- **AR-OTP-001:** theft/replay of the necessary valid bearer browser ceremony secrets together with
  valid authentication evidence is accepted for the current design cycle. Ordinary cookies cannot
  reliably identify the original browser in that case. Existing cookie, expiry, rotation, CSRF and
  server-side invalidation controls remain required. Future DBSC reconsideration is possible,
  without browser-support promises or assuming DPoP equivalence.
- **AR-OTP-002:** external mailbox compromise enabling B's own OTP is accepted as an external
  account security dependency. Users secure their mailbox; UMAXICA still owns secure application
  handling and checks. This does not accept UMAXICA-controlled leakage or general phishing/social
  engineering. Persuaded OTP disclosure has acceptance status **TBC**.

Email OTP is neither phishing-resistant nor achieved NIST AAL2. The ADR's
[versioned official-source analysis](../../adr/email-sign-in-otp-ceremony-binding-and-risk-acceptance.md#standards-and-assurance-limits)
distinguishes ASVS controls, NIST exclusions and product-specific requirements; adding ceremony
binding does not establish standards compliance.

## Unverified behavior

No runtime vulnerabilities or end-to-end conformity were established. In particular, Browser A/B
refusal, concurrent verification/resend, supersession, cookie/session rotation, cancellation,
restart, delivery confidentiality and Base handoff require future public-boundary evidence.
The relation between Rails Session continuity and Auth SID binding, retained `already_verified`
continuation versus strict reuse refusal, exact persistence/keying/comparison mechanics, migration
impact, future cycle and resolution of the Auth freeze are **TBC**. The
[backlog scenarios](../../plans/backlog/email-sign-in-otp-ceremony-binding.md#future-acceptance-scenarios)
are future work, not executed checks.

## Documentation verification

`git status --short`, `git diff --check`, `git diff --name-only` and the scoped documentation
`git diff` were inspected. New untracked documents were reviewed with
`git diff --no-index -- /dev/null <path>`; its exit status 1 indicates the expected new-file diff.
Whitespace and local Markdown link checks passed. The three new documents and `adr/README.md`
are within the authorized scope. Other status/diff entries were pre-existing work, preserved by
this task. No application code, tests, configuration or migrations were changed, and nothing was
committed or pushed. These checks establish documentation hygiene only.
