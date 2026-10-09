# Lightweight Reauthentication and Access Reconfirmation

**Status: Deferred.** Recorded on 2026-10-08. This is a future investigation item, not an accepted
specification, design approval, adoption decision, or implementation plan.

## Background and purpose

UMAXICA may need to reconfirm the signed-in user in selected situations while retaining login
continuity and avoiding a complete restart of ordinary sign-in. Candidate methods are Social Login
through an external Identity Provider (for example OIDC) and Email OTP sent to an already registered
email address. Neither method is selected for a new workflow. The intended experience is
lightweight; it does not inherently provide MFA or NIST AAL2.

Claude and OpenAI confirmation experiences may be UX research references. Their internal protocols,
assurance, and session behavior have not been investigated here; no equivalence to their
implementations is claimed.

## Concepts to keep separate

| Concept                  | Question it answers                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- |
| Authentication           | Which subject has demonstrated control of accepted credentials?                                            |
| Session Validation       | Is the existing session or credential still valid under its current binding, expiry, and revocation rules? |
| Authorization            | May this actor access this application/resource or perform this operation now?                             |
| Reauthentication         | Has the same subject authenticated again through an accepted ceremony?                                     |
| Authentication Freshness | How recently did the relevant authentication event occur, for this purpose and binding?                    |
| Step-up Authentication   | Does new evidence satisfy a higher assurance requirement than the existing context?                        |

A routine access request may need only session validation and current authorization if policy
requires no new authentication event. If policy needs evidence of recent active authentication, a
valid session alone is insufficient and an interactive ceremony may be necessary. The conditions for
either path remain undecided. Reconfirmation does not itself grant application access, establish
real-world identity, or meet a higher assurance level. Freshness, permitted methods, phishing
resistance, and achieved assurance remain separate.

## Investigation scope and candidate use cases

These are candidates, not requirements:

- Reconfirm a user when entering an application if its access policy requires it.
- Request additional confirmation for a long-running session.
- Check a recent authentication fact before a particular operation.
- Match a Social Login or Email OTP result to the existing signed-in subject.
- Reuse suitably bound confirmation for a limited period to avoid excessive prompts.

Compare session validation alone, Social Login, and Email OTP for each candidate. Record interaction
count, accessibility, completion/abandonment, provider or mail availability, account switching,
security evidence, replay exposure, implementation complexity, and operational cost. A recent
provider token issuance or session refresh is not automatically a recent active authentication
event.

## Outside this item

This record authorizes no application, configuration, schema, authentication, or authorization
change. It defines no trigger, endpoint, storage model, TTL, method policy, or rollout. It adopts no
new authentication method and changes no accepted ADR. MFA/AAL2 certification, account recovery,
credential linking, and replacement of current Session Management or Step-up are outside its scope.
Existing full-reauthentication requirements remain binding.

## Standards for future technical investigation

References below were consulted on 2026-10-08; provider support and deployment behavior need
separate investigation when work resumes.

### OpenID Connect Core 1.0

[Core sections 2 and 3.1.2.1](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)
define the following protocol tools:

| Tool           | Use and limitation                                                                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `prompt=none`  | Checks existing provider authentication/consent without UI; may return `login_required` or `interaction_required`. It supplies no new interactive proof.      |
| `prompt=login` | Requests provider reauthentication; it does not select assurance or prove that the returned subject is the current UMAXICA subject.                           |
| `max_age`      | Bounds elapsed time since active provider authentication; exceeding it requires a reauthentication attempt. `max_age=0` is equivalent to `prompt=login`.      |
| `auth_time`    | Time of authentication, required in the returned ID Token when `max_age` is used; evaluate freshness from validated evidence rather than token issuance time. |
| `acr`          | Authentication context class; its meaning and mapping to local assurance require agreement and validation.                                                    |
| `amr`          | Methods used; optional method descriptions alone establish neither local authorization nor NIST AAL2.                                                         |

Study signature, issuer, audience, nonce, transaction binding, and freshness validation together
with provider parameter/claim support. Subject matching should consider validated `iss` and `sub`,
existing effective bindings, and pairwise subject behavior; email equality alone must not select an
Identity. See
[Core sections 5.7 and 8](https://openid.net/specs/openid-connect-core-1_0.html#ClaimStability).
Email OTP is a separately designed email confirmation method, not the OIDC protocol itself.

### Other standards

- [RFC 9470](https://www.rfc-editor.org/rfc/rfc9470.html): a resource server can challenge
  insufficient user authentication with `insufficient_user_authentication`, `acr_values`, and/or
  `max_age`. Investigate its applicability to existing OAuth boundaries; it does not define the
  authenticator, local assurance mapping, or a general browser UI workflow.
- [NIST SP 800-63B-4, assurance levels](https://pages.nist.gov/800-63-4/sp800-63b/aal/) and
  [authenticator requirements, section 3.1.3](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/):
  assess authenticator, assurance, and reauthentication requirements independently. Email is
  prohibited for NIST out-of-band authentication. Email OTP must not be described as a NIST
  out-of-band authenticator or as achieving AAL2; successful mailbox confirmation does not establish
  such compliance.
- [OWASP ASVS 5.0.0 V6](https://github.com/OWASP/ASVS/blob/v5.0.0/5.0/en/0x15-V6-Authentication.md)
  and [V7](https://github.com/OWASP/ASVS/blob/v5.0.0/5.0/en/0x16-V7-Session-Management.md):
  investigate authentication controls, session lifetimes/termination, sensitive-operation
  reauthentication, and federated reauthentication. In particular V7.2.4 token replacement and
  V7.5.1 full reauthentication need reconciliation with the desired continuity UX; preserving login
  continuity cannot imply preserving the same token.

## Relationship to existing UMAXICA design

These references govern existing behavior; this backlog item does not duplicate their contracts.

- **Identity and Persona:**
  [database authority placement](../../docs/architecture/database-authority-placement.md),
  [Persona/Organization authority](../../docs/architecture/persona-organization-authority.md), and
  [Global/Regional ownership](../../adr/global-regional-database-ownership.md) distinguish concrete
  surface principals, identity bindings, Persona resources, and ownership/access. Reconfirming a
  principal cannot establish Persona ownership, delegation, or act-as permission.
- **SSOT and authentication/session state:**
  [Base/Auth/RP authority](../../adr/base-auth-ceremony-and-seven-rp-boundary.md) keeps canonical
  URI/audience registries distinct from runtime authentication facts. Global canonical
  identity/Persona data is also distinct from session authority and transient ceremony evidence.
  Investigate each fact's existing owner; do not create a second identity, authorization, or
  freshness source of truth.
- **Token DB:** [Token/Symbol/Mark history](../../adr/token-symbol-mark-database-boundary.md)
  records the original split; current `AppTicketRecord`, `ComTicketRecord`, and `OrgTicketRecord`
  use surface-local `app_ticket`, `com_ticket`, and `org_ticket` pools.
  [Session/token authority](../../docs/security/session-token-authority.md) separates physical
  storage from authority. Existing ticket storage is context, not a decision to store new
  reconfirmation results there; persistence and lifetime remain open.
- **Rails and Edge:**
  [current Base/Auth/RP map](../../docs/architecture/base-auth-seven-rp-boundary.md) places
  session/token authority at Base and credential ceremonies at Auth. Core, Warp (registered `side-*`
  clients), and Edit retain independent RP credentials. The
  [Core zero-cookie UI boundary](../../adr/tanstack-start-zero-cookie-ui-origin-boundary.md)
  reserves authentication handling for Rails/browser contracts; TanStack/Edge presentation does not
  gain credential or freshness authority. Its Edge deployment evidence remains deferred. Future UX
  must preserve the applicable surface, issuer, audience, and transport boundaries.
- **Session Management:** [session/token authority](../../docs/security/session-token-authority.md)
  and [logout management](../../docs/security/logout-session-management.md) govern refresh,
  revocation, and logout. RP-only revocation currently stops new issuance/refresh without
  immediately invalidating an issued Access JWT. Study reconfirmation against that contract, parent
  DeviceSession/Browser Session binding, session limits, and compromise handling.
- **AAL and Step-up:** [assurance ADR](../../adr/authentication-assurance-level-boundaries.md)
  includes superseded historical product AAL wording; use its supersession notices and
  [current operation inventory](../../docs/security/step-up-operation-inventory.md). Explicit
  operation requirements and mutation-time checks govern; normal freshness and full reauthentication
  are distinct, and current full reauthentication replaces the root token. Existing 15-minute normal
  Step-up freshness is not a proposed TTL for this item.
- **Social Login and Email OTP:**
  [identity resolution/binding](../../docs/security/identity-resolution-and-credential-binding.md)
  describes verified issuer/subject binding and effective contact ownership. Existing Social Login
  finalization and Email OTP challenge code are starting points for a future audit, not proof of
  suitability for this new purpose.
  [Social linking ADR](../../adr/social-identity-linking-requires-step-up.md) preserves separate
  account-owner approval; provider authentication cannot replace it.
  [Current method policy](../../docs/security/authentication-assurance-levels.md) permits Email OTP
  for APP/COM normal Step-up, excludes it from ORG authentication/Step-up, and does not claim NIST
  AAL2. This record expands no surface's method set.

Older Sign/Acme/Side wording, historical AAL labels, and older provider backlog descriptions must be
read with later supersession/reconciliation notices and current code. Reopening this item requires
an audit of the then-current contracts, not adoption of historical tables. The related
[Auth/Xper deferred redesign](auth-xper-transient-workflow-redesign.md) concerns transient workflow
infrastructure; this item leaves its design choices undecided.

## Security considerations for a future threat analysis

Investigate stolen sessions, cross-surface/cross-account confusion, provider account switching,
login CSRF, forged or stale assertions, callback replay, and reuse across purposes or tenants.
Matching the existing subject is distinct from adding or replacing its credentials.

For Email OTP, assess mailbox compromise, shared/forwarded mail, address reassignment,
phishing/relay, delivery delays or failures, guessing, resend abuse, and OTP reuse or concurrent
consumption. Study effective registered-contact ownership, transaction/session/purpose binding,
expiry, atomic one-time consumption, shared attempt budgets, and privacy-preserving refusals. These
are investigation topics; no new limits or recovery behavior are chosen here. Plan observability
that protects codes, tokens, credentials, and sensitive request data.

## Open questions

- Which application, operation, elapsed time, or risk conditions need reconfirmation, and where are
  session validation and authorization alone sufficient?
- Who owns the result, where is it stored, and what actor/session/resource/tenant/purpose bindings
  are required across Rails and RP boundaries?
- What validity period and reuse scope are acceptable, and what clock/evidence establishes
  freshness?
- How do refresh, root-token replacement, RP/parent revocation, logout, session limits, credential
  changes, and compromise affect confirmation validity?
- Which validated provider `iss`/`sub` and effective-binding conditions demonstrate the same
  subject, including pairwise IDs and account switching? What if required claims are unavailable?
- For which surfaces and purposes is Email OTP acceptable, and when is stronger evidence necessary?
- What happens on mismatch, cancellation, expired/replayed OTP, delivery delay, provider/store
  failure, or unavailable methods? Which operations are refused, and can unrelated login continue?
- Should this capability integrate with existing Step-up or remain separate? Which existing
  operations require full reauthentication or stronger assurance and cannot use it?

## Conditions for resuming consideration

Resume only when a concrete product/access need and responsible owner are identified and the
relevant Base/Auth/RP and Edge deployment boundaries are understood. Start with a current-code/ADR
inventory, provider capability investigation, and threat analysis. Compare UX, security, and
complexity before proposing requirements. Any proposal must explicitly resolve the open questions
and applicable ASVS/NIST constraints, and obtain separate design and implementation authorization
through the [planning lifecycle](../README.md).

This file is the local deferred investigation task. No active GitHub issue, delivery date, approved
design, or implementation commitment is created by recording it.
