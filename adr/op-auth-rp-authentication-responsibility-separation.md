# OP, Auth, and RP Authentication Responsibility Separation

## Status

**Accepted (2026-10-22): architecture principles agreed by the Owner.** Direct-path protocol
and implementation details listed under Open Questions are not accepted specifications. This
record changes documentation only and certifies no implementation, deployment, or test result.

This ADR is the canonical decision for the three paths and their logical responsibility split.
It partially supersedes the Base-as-physical-OP-and-self-RP model in
[Base authority and self-RP separation](base-authority-and-self-rp-separation.md) and
[Base/Auth boundary](base-auth-ceremony-and-seven-rp-boundary.md), only where those decisions
require application Base and the OP to remain the same component or require all authenticated
management/step-up requests to be mediated by that authority. It also partially supersedes the universal authority-only grant/freshness assignment in
[Acme session authority](acme-session-and-token-authority.md),
[credential gateway](sign-credential-gateway-surface.md), and
[residual IdP retirement](sign-residual-idp-surface-retirement.md) for authenticated RP direct
paths. Their prohibition on Auth owning application sessions or authorization remains accepted.
Physical Base-as-OP statements in [Sign In First](sign-in-first-and-sign-up-handoff.md),
[sign-up handoff](sign-up-authentication-handoff-and-social-rt.md),
[social linking](social-identity-linking-requires-step-up.md), and
[Identity-centric AAA](identity-centric-aaa-architecture.md) are read through this separation;
their independent admission, account-owner approval, and Accounting decisions are retained.
Existing protocol, credential, Identity, admission, and revocation safeguards remain in force
within their applicable scope.

## Context

Earlier ADRs deliberately separated Base authority controllers from Base self-RP controllers
on one FQDN. The accepted direction now separates the OP from application RP responsibilities;
Base becomes one of the RPs. Keeping an OP authentication session is independent of acting as
an application RP. Removing the latter responsibility does not remove the former session.

Existing Base-to-Auth admission and result contracts provide concrete security constraints, but
are coupled to Base/root context. They are not an already-decided protocol for independently
operated authenticated RPs. A new protocol must preserve their protections without silently
giving Auth account authority or making a direct ceremony another login issuer.

## Decision

### Components and state owners

| Subject | Logical owner |
| --- | --- |
| OIDC authentication request, transaction, and response | OP |
| OP authentication session, when maintained | OP |
| Passkey registration, authentication, management UI and processing | Auth |
| Social Login authentication and linking ceremony UI and processing | Auth |
| Step-up identity verification | Auth |
| Application session | Each RP |
| Application authorization, including the operation after step-up | Requesting RP |
| General account-management UI and initiation of method management | Base, as an RP |
| General account settings | Base, under existing domain authorization |

The OP controls Sign In as the OIDC Provider, validates Auth evidence, and completes OIDC.
It delegates actual credential authentication to Auth and does not own RP-specific application
features or account-management UI. It may maintain its own authentication session for SSO.

Auth is an independent authentication component used by the OP and authenticated RPs. It keeps
WebAuthn on the fixed Auth origins of the existing surface-specific configuration, and retains
temporary-token cooperation with the OP. Auth is neither the UMAXICA OIDC OP nor an application
OIDC RP. Its role as a WebAuthn Relying Party is a separate protocol concept and is compatible
with these constraints. An upstream provider ceremony does not make Auth a UMAXICA application RP.

Every RP validates the OP's OIDC result, manages its own application session, and decides its
own application authorization. Base owns account-management navigation, while delegating actual
Passkey and Social Login method-management ceremonies to Auth. Auth's processing responsibility
confers no unilateral power to select or change the target account, grant application permission,
issue a login session, or change account lifecycle state.

This table specifies logical responsibilities, not new database placement, table authority,
physical hosts, routes, client registrations, or Identity/Account ownership contracts. APP, COM,
and ORG stay independent trust boundaries. Existing authorized domain writers retain their
contracts until a separately accepted change replaces them.

### A. Ordinary Sign In: RP → OP → Auth → OP → RP

1. The RP starts Sign In through the OP when an authenticated application session is needed.
2. The OP accepts and validates the OIDC request and evaluates existing authentication state and
   request conditions. When authentication is needed, it delegates to Auth using the existing
   temporary admission/result mechanism.
3. Auth performs the required identity verification and returns bound evidence to the OP.
4. The OP validates that evidence and completes OIDC under the canonical Sign In admission rules.
5. The RP validates the OIDC result and establishes its own application session.

This is the basic Sign In path. An existing valid OP session may satisfy the request without
another Auth visit under the existing `prompt` and `max_age` contract. `prompt=none` does not
start an interactive ceremony. No valid RP session means Sign In through the OP, rather than a
direct management or step-up ceremony that manufactures a session.

[Sign In First](sign-in-first-and-sign-up-handoff.md) remains authoritative: completed Sign Up
enters canonical Sign In admission; registration completion alone grants no session. Its old
physical Base-authority wording now refers to the OP role. Durable registration survives a later
Sign In failure. This ADR changes no sign-up state machine or unresolved invitation decision.

### B. Authentication Method Management: Base → Auth → Base

An authenticated Base user starts Passkey registration/addition/removal/management or Social
Login link/unlink/management from Base account UI. Auth owns the method-management ceremony and
returns a verified result to Base. Ordinary management does not require routing through the OP.
If Base's authenticated session is invalid, Base requires path A.

A session alone is insufficient authorization for sensitive credential changes. Existing
re-authentication, step-up, bootstrap, no-lockout, immutable ownership, uniqueness, release-history,
and concurrency rules remain prerequisites. Auth executes an authorized account-bound intent;
it does not choose another account or take ownership of the Identity/Account source of truth.
Final mutation and evidence acceptance must respect existing domain authority. The post-separation
Auth-to-authoritative-writer contract remains an Open Question.

Social Login for ordinary Sign In follows path A; authenticated account linking follows path B.
Provider authentication proves control of the external identity, not approval by the UMAXICA account
owner. [Social linking](social-identity-linking-requires-step-up.md) retains fresh, account-bound
step-up for APP linking and unlinking and the no-lockout guard. This ADR adds no provider to COM
and no self-service ORG linking or provisioning capability.

### C. Step-up Authentication: RP → Auth → RP

1. The RP verifies that its current authenticated session is valid and initiates additional
   authentication for a specific user and operation.
2. Auth verifies the additional factor and returns evidence to that RP.
3. The RP validates evidence and its binding to the user, requesting RP, operation, and original
   session or transaction; it re-evaluates policy before authorizing the protected operation.

An OP visit is unnecessary solely for step-up. The direct path requires an existing valid RP
session, including at evidence acceptance. It cannot establish a new Sign In session or revive an
expired, displaced, or revoked one. An invalid session returns to path A. Auth success is evidence,
not application authorization; browser-delivered values alone never justify unconditional elevation.

Direct step-up does not automatically change `auth_time` or `acr` in an ID Token previously
issued by the OP. This decision grants no Auth authority to rewrite OP authentication state or
issue OP tokens. Any later OP issuance remains governed by its own validated OIDC contract.

### Temporary request and result security

The existing OP–Auth temporary-token cooperation remains; WebAuthn processing stays on Auth.
[Base/Auth boundary](base-auth-ceremony-and-seven-rp-boundary.md) specifies opaque 256-bit,
digest-only, 60-second, atomically consumed admission/results, with purpose/surface binding and
later browser-binding and result-purpose amendments. Its D-82 admission binds the initiating
browser, Auth-local continuity, parent transaction and root context; GET displays continuation,
receiver-local CSRF-protected POST performs the protected step. Those existing contracts are
preserved for their existing paths, not generalized into a new RP protocol by this ADR.

Direct paths also require trustworthy temporary requests/results. The following are accepted
security requirements; their concrete realization remains undecided:

| Concern | Required property and remaining design work |
| --- | --- |
| Request issuer and verifier | Explicit trusted issuance and Auth validation; select authorities and protocol separately. |
| Requesting RP | Authenticate the registered requesting RP and bind results to that RP; define trust establishment. |
| Account | Bind an authorized server-selected subject and surface; Auth cannot substitute a browser-selected account. |
| Purpose and operation | Separate login, registration, link/unlink and step-up intents; bind operation and applicable resource/tenant. |
| Expiry and consumption | Bounded lifetimes and one-time consumption; select direct-path deadlines and retry receipts. |
| Replay, redirects, CSRF | Reject replay and destination substitution; validate trusted return targets and retain CSRF/browser correlation. |
| Original RP session | Correlate original session/transaction and recheck validity before acceptance and authorization. |
| Success and non-success | Distinguish success, failure, cancellation and expiry; only validated success may satisfy the requested proof. |
| Server-side verification | Validate against trusted server-side authority; decide whether authenticated back-channel exchange is necessary and how it works. |
| State writers | Auth records verification evidence; RP decides operation authorization and its session-local proof; existing domain owners control account mutation and OP state. |

Neither a signed browser token nor an opaque reference alone establishes session validity or
operation authority. No token format, signing key, issuer, exchange endpoint, or general direct-path
admission protocol is selected here. Existing signed credential-specific contracts are not
implicitly retired or promoted to that general protocol.

### Existing policy decisions retained

[Security Mode](authentication-security-mode.md), section D, already decides method sets and
maximum proof validity: NORMAL APP uses Email OTP/Passkey/TOTP, NORMAL COM Email OTP/Passkey,
and ADVANCED uses Passkey (ORG is ADVANCED only); maxima are 15 minutes and 5 minutes respectively.
Evidence is actor-, session-, operation-, and target-bound and consumed once. These are existing
accepted policy limits, not newly invented direct-path token lifetimes or verified implementation.
The exact direct-path operation policy and enforcement remain to be specified within those limits.

Its section E retains purpose-limited Email OTP reauthentication for a NORMAL first Passkey,
separate deletion reauthentication and active-count checks, and no session revocation merely for an
individual Passkey change. The [2026-10-15 consolidation](authentication-security-cycle-consolidation-2026-10-15.md)
replaces the old one-Passkey ADVANCED minimum with two, and replaces required-AAL authorization with
explicit authentication conditions. Step-up success is not a claim of NIST AAL2. Later
[identifier-first](passkey-identifier-first-sign-in.md) and
[account-label](passkey-authenticator-account-label.md) decisions remain unchanged.

[Credential binding](identity-resolution-and-credential-binding.md) retains immutable credential
ownership, authoritative finalized bindings, writer serialization and released-binding history.
APP social resolution uses verified issuer/subject; the separate
[ORG Entra contract](org-entra-id-sign-in-boundary.md) retains tenant/object lookup and no JIT
provisioning, subject to its recorded amendments. A browser field or provider email cannot change
the account targeted by an authenticated management request.

### WebAuthn Level 3 and Related Origin Requests

[WebAuthn Level 3, section 5.11](https://www.w3.org/TR/webauthn-3/#sctn-related-origins)
describes Related Origin Requests (ROR). UMAXICA continues to execute WebAuthn on fixed Auth
origins. ROR is neither a prerequisite of OP/RP separation nor authorization to remove Auth or
distribute Passkey execution to the OP or individual RPs. Future adoption, migration, and browser
compatibility are outside this decision. WebAuthn RP ID, browser origin, and OIDC RP identity remain
distinct concepts. This ADR changes none of their configured values.

## Reconciliation with existing ADRs and implementation

| Existing contract | Relationship to this decision |
| --- | --- |
| Base authority/self-RP and Base/Auth boundary | Partially superseded for physical Base/OP co-location and obligatory authority mediation of authenticated direct paths; retain OIDC, temporary admission, browser-binding and ceremony safeguards. |
| Identity authority and historical credential-gateway/retirement ADRs | Retain general account management at Base and no Auth account/session/authorization authority. Replace any universal OP-only grant/freshness requirement for the new direct paths; their protocol is pending. |
| Sign In First and sign-up authentication handoff | Preserve canonical Sign In admission; physical Base-as-OP wording is historical for the separated target. |
| Social linking and provider callback ADRs | Preserve account-owner step-up, no-lockout and provider-specific validation; Auth linking processing is not unilateral account-binding authority. |
| Identity-centric AAA and Chronicle | Preserve Identity, Authentication, Authorization and Accounting as distinct responsibilities and Chronicle as audit evidence; old Base-session-authority wording splits into OP and RP roles. No new database or audit platform. |
| Shared-store logout and separated-store logout | Preserve the activation-specific contracts; direct authentication grants no revocation bypass or session resurrection. |

Read-only implementation inspection on 2026-10-22 found the existing combined-Base model in
`app/services/base_auth_admission_coordinator.rb`,
`app/operations/base_step_up_admission_issuer.rb` and
`app/controllers/concerns/base_step_up_completion.rb`: admissions/finalization depend on Base
browser/root context. Completion also explicitly reissues Base self-RP credentials with an
authentication event and assurance claims. That is an existing explicit issuance path, not evidence
that arbitrary RP direct step-up is implemented or can mutate an already-issued OP ID Token.
`app/controllers/concerns/auth_step_up_result_handoff.rb` returns a reference through the existing
coordinator; it is not a general authenticated multi-RP result exchange.

`app/services/oidc_authorize_coordinator.rb` validates requests and issues authorization responses;
`app/controllers/concerns/passkey_ceremony_context.rb` binds WebAuthn challenges to surface, RP ID,
origin, purpose and actor. `app/consumers/identity_passkey_ceremony_result_consumer.rb` separately
checks signed credential-result bindings. `app/services/social_auth_link_handler.rb` locks the
current account, rejects foreign ownership/released history and records a social audit outbox.
These existing mechanisms must be mapped by ownership, not copied as proof of a new trust contract.

Current documentation in `docs/identity/authority-boundary.md`,
`docs/security/credential-gateway.md` and `docs/security/step-up-operation-inventory.md` still
uses the Base-centered authority and step-up implementation model. The operation inventory lists
a current 15-minute normal-step-up deadline, whereas the accepted Security Mode target distinguishes
NORMAL/ADVANCED maxima. This ADR preserves that distinction between current documentation and
accepted target; it neither certifies the target as implemented nor updates current-behavior docs.

Related tests inspected include `test/operations/base_step_up_admission_issuer_test.rb`,
`test/services/base_auth_admission_coordinator_test.rb` and
`test/integration/social_link_unlink_test.rb`. They describe existing bindings and guards; no
runtime tests were run for this documentation-only decision and no direct-path coverage is claimed.

## Open Questions

1. **Direct-path token specification:** request/result representation, issuance, exchange,
   lifetimes, consumption and retry receipts. Existing OP–Auth and credential-specific formats do
   not settle the general RP contract.
2. **Issuance/validation and trust boundary:** who issues and validates each request/result, how
   Auth authenticates RPs, keys/registration ownership, and whether/how server-to-server validation
   occurs without depending on shared OP database access.
3. **Step-up policy integration:** apply the existing mode maxima, method sets and one-time
   operation/target binding to each direct-path operation; decide any narrower windows, strength
   requirements and transaction/session proof storage. These policy baselines are already decided.
4. **Method-management reauthentication:** preserve the cited Passkey and APP social requirements;
   specify remaining per-operation conditions, bootstrap/recovery exclusions and direct-path
   enforcement without treating every existing session as sufficient.
5. **Auth and Identity/Account authority:** map existing authoritative binding owners to authorized
   post-separation writers, including mutation authorization and races. Physical data placement and
   a new cross-component update API are not decided here.
6. **Audit evidence:** Identity-centric AAA and Chronicle already decide the evidence domain and
   separation from authorization/telemetry. Direct-path event catalog, correlation, recorder,
   durable delivery, deduplication and operation-specific audit failure behavior remain open;
   existing outbox contracts and secret-minimization rules remain applicable.
7. **Revocation impact:** preserve shared-store logout until activation of a separated RP; then
   apply [OP-commit and BCL](first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
   (R5 activation), including its bounded residual acceptance. Mapping pending Auth requests,
   accepted proof and cancellation to that lifecycle remains open. No new exception is granted.
8. **Failure, interruption, concurrency and network faults:** define terminal outcomes, safe
   recovery, idempotent retries and late-result rejection for the direct paths. Existing admission
   restart safeguards remain applicable; Sign In First D14 is still unresolved. Failure cannot
   become success or restore a session.
9. **External IdP linking protocol:** retain
   [APP callback transport](social-omniauth-callback-transport.md),
   [COM exclusion](sign-com-no-social-login.md), and amended ORG Entra sign-in constraints.
   They do not settle every post-separation provider linking contract, callback-intent correlation,
   unlink lifecycle or provider failure. No new provider/surface support is accepted.

## Consequences and future implementation verification

The three paths share Auth credential expertise while keeping login admission and application
permission with their owners. Direct authenticated operations avoid an unnecessary OP visit;
they introduce explicit RP–Auth trust and evidence-validation work that must precede implementation.
The split requires ownership mapping rather than moving all historical Base authority into Auth.

A future implementation must verify all three paths, valid OP-session SSO and request conditions,
invalid/revoked/displaced RP sessions at start and completion, and the prohibition on direct login
or resurrection. Exercise wrong user/RP/surface/purpose/operation/session, replay, redirect
substitution, CSRF, expiry boundaries, success/failure/cancellation, concurrency and lost responses.
Verify method-management step-up/no-lockout/ownership and provider callback binding; fixed-origin
WebAuthn verification; unchanged historical OP claims; policy re-evaluation at the protected
operation; revocation during an outstanding ceremony; and secret-free durable audit outcomes.
Protocol details must be separately settled before those checks can certify implementation.
