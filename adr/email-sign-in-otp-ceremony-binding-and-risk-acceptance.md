# Email Sign-In OTP Ceremony Binding and Risk Acceptance

Documentation capture supplied with date **2026-10-12**; decision discussion: **2026-10-11**.
The supplied date is retained as document metadata, not a claim that verification occurred on
that date. Implementation status: target contract; implementation is neither approved nor
delivered by this documentation change.

## Status

Accepted (2026-10-11). User-approved security decisions and limited product risk acceptances.

Decision A is an **ACCEPTED TARGET SECURITY REQUIREMENT — NOT YET VERIFIED AS IMPLEMENTED**.
Decision B is an **ACCEPTED SECURITY INVARIANT**. This ADR records a future security contract;
acceptance establishes neither implementation conformity nor deployment or standards compliance.
No authentication implementation is authorized by this documentation decision.

## Context and scope

APP and COM Email Sign-In are the target. Each surface also has Email and Telephone Sign-Up and
Email Step-Up: eight OTP route families in total. Sign-Up and Step-Up retain their separate existing
ticket/transaction bindings. Telephone remains Sign-Up only. Their redesign requires a separate
decision.

The [Base/Auth authority ADR](base-auth-ceremony-and-seven-rp-boundary.md) separates Auth-local Rails
Session continuity, a server-side Auth Ceremony Session, a random HttpOnly host-only Auth ceremony
cookie, and Base-owned Browser Session/OIDC/token authority. Cookie possession locates continuity;
it does not itself prove that an OTP was issued within that ceremony or grant Base/RP authority.

The [current source inspection](../docs/security/email-otp-ceremony-security-boundary.md) found
ceremony-specific challenge and resend controls already present. The premise that current sign-in
calls `CommonOtp#verify_otp_code_and_consume` is outdated for the examined local tree. The
[race-condition ADR](email-otp-race-condition-fixes.md) records that historical locked-consumption
protection; its later amendments and
[realm-separated identifier ADR](realm-separated-identifiers-and-dead-history.md) describe its
replacement/removal. Existing locking is protection, not evidence of a demonstrated double-consume
vulnerability. Retained verified-result behavior still requires acceptance reconciliation.

## Decision

### A — Bind Email Sign-In OTP to its originating Auth Ceremony

An OTP issued within an APP or COM Auth authentication ceremony MUST be accepted only by that same
authorized ceremony and its corresponding browser-session continuity context. A code issued for
Ceremony A MUST be refused by independently admitted Ceremony B even for the same account and
email credential. Missing, stale, mismatched, revoked, superseded or otherwise invalid binding MUST
fail closed before authentication evidence or session issuance.

The future proof MUST establish the relationship between OTP issuance, Auth-local Rails Session
continuity, server-side ceremony, admission and cookie continuity. A valid ceremony cookie alone
does not establish this relationship. A Rails Session identifier is not assumed to be the correct
or stable binding secret: rotation and `reset_session` require explicit design. A separate random
continuity nonce or authenticated server-side reference may be needed. Exact persistence, keying,
rotation and comparison mechanics are **TBC**, starting from existing Auth Ceremony architecture.

Binding secrets MUST remain outside email messages, URLs, browser-readable security-token storage
and logs. This rule distinguishes secret binding material from an encrypted resend authorization
envelope or a non-secret reference; any future browser-visible envelope requires an explicit
confidentiality and authorization review. Auth MUST remain ceremony-only; Base retains Browser
Session, OIDC and downstream credential authority.

### B — Preserve one-time OTP consumption

A successfully consumed OTP MUST never be accepted again. Concurrent requests MUST produce at
most one successful consumption. Resend/replacement MUST invalidate the
superseded generation and preserve the applicable failure budget. Code reuse after consumption is
distinct from first-use theft of an unconsumed code.

The accepted invariant is not permission to turn retained verified evidence into another OTP
acceptance. Current `already_verified` continuation behavior must be reconciled with this strict
contract in the future design, including exactly-once consumption and authorized handoff retry.
That reconciliation is **TBC**; no demonstrated runtime violation is asserted here.

### C — Apply the same requirement to resend

Resend MUST preserve ceremony and continuity authorization without detachment, bypass, transfer or
a silently weaker model. Current encrypted resend state uses the admitted ceremony's SID digest in
its authenticated purpose, includes surface and Contact/owner binding facts, and the resender checks
the current challenge. It is more narrowly bound than email target and surface alone; explicit
ceremony ID and challenge generation are absent from its payload. Restart, rotation and generation
semantics remain verification/design questions, not confirmed defects.

## Threat scenarios and rationale

**Threat scenario A — cross-ceremony first use:** A receives an OTP; independently admitted B for
the same account submits A's code. Decision A requires refusal even though B has a valid cookie.
Atomic consumption alone would only choose a winner if both ceremonies could accept the same code;
binding addresses authorization before that consumption.

**Threat scenario B — mailbox compromise:** an adversary starts legitimate ceremony B for the
victim's email and obtains B's own OTP through the compromised external mailbox. Binding to B alone
cannot prevent B's use of that evidence. This is AR-OTP-002, distinct from cross-ceremony acceptance.

## Accepted residual risks

### AR-OTP-001 — Theft and replay of browser ceremony secrets

**ACCEPTED FOR THE CURRENT DESIGN CYCLE**, by the user on 2026-10-11. Browser continuity relies on
bearer-style secrets, including Auth Ceremony and Rails Session cookies. An adversary possessing
the necessary valid continuity secrets together with valid authentication evidence cannot reliably
be distinguished from the original browser by ordinary cookie controls.

Existing HttpOnly, Secure, SameSite, host-only, expiry, rotation, CSRF and server-side invalidation
protections MUST be preserved. Future device-bound browser session mechanisms, including relevant
DBSC developments, may prompt reconsideration; availability and guarantees are not promised.
DPoP is not automatically equivalent to cookie-bound browser authentication.

### AR-OTP-002 — Compromise of the user's external email account

**ACCEPTED AS AN EXTERNAL ACCOUNT SECURITY DEPENDENCY**, by the user on 2026-10-11. The user is
responsible for securing the external mailbox receiving UMAXICA OTPs. This accepts threat scenario
B as a limitation of email authentication. UMAXICA remains responsible for preventing leaks through
its own logs, queues, responses and delivery handling, and for enforcing authentication checks.

This acceptance does not cover all phishing or social engineering. Persuading a user to disclose
an OTP is a distinct known limitation of manually entered codes; its acceptance status is **TBC**.

## Non-accepted risks

The above acceptances do not authorize cross-ceremony OTP acceptance, successful reuse after
consumption, concurrent double consumption, ceremony-admission bypass, UMAXICA-controlled OTP or
session/binding-secret leakage, silent authentication downgrade, or Base/RP authority derived
merely from an Auth cookie. Email OTP MUST be described without a phishing-resistant or achieved
NIST AAL2 claim. Unverified behavior MUST remain distinguished from confirmed failures.

## Alternatives considered

- Account/email-only OTP acceptance cannot prove the originating ceremony.
- Cookie-presence-only admission cannot prove a particular OTP's issuance binding.
- Direct Rails Session ID binding needs rotation/stability analysis before adoption.
- Existing Auth SID/parent challenge binding, a separate random continuity nonce, or another
  authenticated server-side reference remain implementation candidates; selection is TBC.
- Removing Email Sign-In or requiring a different authenticator is a separate product decision;
  a general MFA, Passkey management or account-recovery redesign is outside this decision.

## Consequences and deferred implementation

The [backlog](../plans/backlog/email-sign-in-otp-ceremony-binding.md) records future scenarios and
design questions. It is **BACKLOG — NOT STARTED** even though related controls exist locally. The
[Auth/Xper freeze](defer-auth-xper-transient-workflow-redesign.md) and its narrow D-82 admission
exception remain in force. This ADR does not widen that exception. Future implementation cycle,
freeze conflict resolution and any necessary amendment are **TBC** before implementation. Potential
persistence/migration impact is TBC; no migration is selected or authorized here.

## Standards and assurance limits

Official sources checked on 2026-10-11:

- [OWASP ASVS stable releases](https://github.com/OWASP/ASVS/releases): version **5.0.0**, tag
  `v5.0.0_release`, source commit `5cf9b032440be53ce345ab3c130fda46ba1ce7a2`; Bleeding Edge is excluded.
  [Authentication requirements](https://github.com/OWASP/ASVS/blob/v5.0.0_release/5.0/en/0x15-V6-Authentication.md)
  include single use (`v5.0.0-6.5.1`) and original-request binding (`v5.0.0-6.6.2`). They inform
  product controls, not a compliance assertion. `v5.0.0-6.3.6` excludes email authentication at L3.
- [OWASP MFA Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html#email)
  is living guidance, without a numbered stable release; the consulted edition is dated by this
  retrieval. It identifies mailbox dependence and susceptibility to phishing.
- [NIST SP 800-63B-4 final](https://csrc.nist.gov/pubs/sp/800/63/b/4/final), published July 2025:
  [§3.1.3](https://pages.nist.gov/800-63-4/sp800-63b.html#ooba) excludes email as out-of-band
  authentication, and [§3.2.5](https://pages.nist.gov/800-63-4/sp800-63b.html#phishing) excludes
  manually entered OTPs from phishing-resistant authentication. Ceremony binding does not change
  those classifications or establish NIST AAL2. Product assurance labels in
  [authentication assurance levels](../docs/security/authentication-assurance-levels.md) are not
  standards certification.

## Supplemental decision capture: D1–D4

This capture preserves the supplied security decision while retaining the local-source findings
above. Its historical premise concerns public feature snapshot
`6fa6867d44b5499632079775cb0fb22cbfddd339`, potentially older than the local tree. At that snapshot,
the supplied inspection described admitted Auth ceremonies, credential-scoped sign-in OTPs and
atomic `CommonOtp#verify_otp_code_and_consume` consumption, without a visible originating-ceremony
comparison. This supported a potential cross-ceremony first-use misuse, not an executed two-browser
exploit. The local inventory above records a later implementation and supersedes that premise for
local-code descriptions. Reinspect local feature HEAD before implementation.

### D1 — Bind each APP/COM Email Sign-In issuance to its originating ceremony

- An issuance in admitted Auth Ceremony A MUST authenticate only A, even when B targets the same
  email credential and account.
- The server MUST associate each issuance/generation with its authorized Auth Ceremony and the
  relevant local browser-session continuity context. Verification MUST check this association,
  surface, target credential, purpose, generation, expiry and unconsumed state before accepting.
- Missing, inconsistent, expired, replaced, canceled or revoked binding MUST fail closed before
  usable authentication evidence or Base session establishment.
- Server-side Auth ceremony identity is the primary continuity object; Rails cookie-backed
  continuity is a separate check. `session.id` is neither assumed immutable nor sufficient as a
  binding secret. Nonce, digest, storage and rotation contracts remain TBC.
- Binding material MUST be server-verifiable, opaque and unpredictable. Raw cookies, session
  secrets and OTP binding secrets MUST remain outside emails, URLs, client-visible props, logs,
  analytics and audit metadata.
- Possession of the required ceremony/session secrets proves bearer continuity, not physical
  browser or device identity.

### D2 — Preserve one-time verification and limit guessing

- Verification and consumption MUST remain atomic; concurrent correct submissions MUST yield at
  most one successful consumption.
- Consumption invalidates the OTP. Replacement MUST supersede the previous generation, including
  concurrent browser use; the policy for independently active ceremonies remains TBC under D3.
- Failed-attempt accounting, cooldowns, short finite expiry, delivery safeguards and generic denial
  remain mandatory. Resend or browser restart MUST preserve credential-level attempt budgets.
- The historical `CommonOtp#verify_otp_code_and_consume` row lock is an existing protection, not
  evidence of double-use exploitation. Preserve equivalent current challenge guarantees; this
  decision does not require restoring the removed helper.

### D3 — Apply the same policy to reissue and resend

Issuance, verification, consumption, supersession and resend MUST enforce the same ceremony
association. An encrypted resend-state token alone cannot authorize issuance for a different
ceremony. The supplied historical `SignInOtpResendState` inventory described kind, surface and
target without originating ceremony; the local SID-purpose binding described above must also be
considered. Neither inventory establishes a production exploit. Whether a credential has one
active OTP globally or one per ceremony, and the effects on delivery, abuse prevention and parallel
attempts, remain TBC.

### D4 — Preserve authority and surface boundaries

The target covers APP/COM Email Sign-In only. Telephone remains Sign-Up contact confirmation,
without Sign-In or Step-Up authority. Email/Telephone Sign-Up and Email Step-Up retain their own
flow/transaction binding models. Auth remains ceremony-only; Base alone commits Browser Sessions
and downstream authority. Auth-issued session tokens or Auth cookies promoted to authentication
proof are outside this decision. The Auth/Xper freeze and its D-82 exception remain unchanged;
implementation requires separately authorized scope and scheduling.

## Residual-risk governance and review triggers

Assigned owner, likelihood, impact assessment, next review date and expiry are **TBC**. These
bounded product acceptances are not a complete formal risk-register record.

**AR-OTP-001** accepts, for this cycle, an adversary holding the necessary active Auth and Rails
continuity secrets plus otherwise valid authentication evidence. It does not accept secret leakage,
expired/revoked continuity, CSRF bypass, weakened Secure/HttpOnly/host-only/SameSite protections,
unrelated-ceremony acceptance, or treating a cookie alone as successful sign-in. Review triggers
include suitable independently reviewed device-bound credentials such as DBSC, credible cookie
replay incidents, material browser/platform changes, or new evidence of an exploitable ceremony
boundary. DPoP is not automatically a device-bound browser-cookie substitute.

**AR-OTP-002** accepts the external mailbox trust dependency: an adversary admits independent B,
obtains B's legitimately issued OTP from a compromised mailbox, and signs in where no further factor
is required. Binding cannot reject the actual issuing ceremony. Users manage their external mailbox;
UMAXICA still owns OTP generation, delivery integration, storage, logging, authorization,
enumeration resistance, abuse safeguards and session issuance. This is not permission to omit them.
Deceptively persuading a user to disclose a code without mailbox compromise remains **TBC**.

The existing Email OTP exception in [OTP audit](../docs/security/otp-audit.md) and
[assurance levels](../docs/security/authentication-assurance-levels.md) remains an explicit product
exception to NIST's email out-of-band prohibition. It grants neither NIST AAL2 nor phishing
resistance and does not mandate MFA for every sign-in.

## Supplemental consequences and follow-up

The [supplied historical/current-target boundary capture](../docs/security/email-sign-in-otp-ceremony-security-boundary.md)
distinguishes the public snapshot from the retained local inventory. The
[backlog](../plans/backlog/email-sign-in-otp-ceremony-binding.md) stays **BACKLOG — NOT STARTED**.
Before implementation, review local HEAD, Auth/Base decisions and every admission/resend/result
consumer; select the binding model; define crash/retry, rotation, concurrency and active-code policy;
and authorize the implementation cycle. This ADR makes no runtime change or D1 conformity claim.
