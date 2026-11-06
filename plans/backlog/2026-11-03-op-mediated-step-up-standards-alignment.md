# OP-Mediated Step-Up (Two-Step) Redesign And Standards Alignment

Date: 2026-11-03

Status: Backlog. Design direction recorded from an owner discussion; nothing is decided in an ADR or
implemented.

Related:

- `adr/op-auth-rp-authentication-responsibility-separation.md` (accepted 2026-10-22; path C
  conflicts with this direction)
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/step-up-authentication-redesign.md`
- `adr/authentication-security-mode.md` (method sets and proof maxima)
- `plans/backlog/2026-11-03-chronicle-retention-policy-reference-rows.md`

## Direction (owner, 2026-11-03)

- Step-up must be able to serve any RP, not only Base. Today it is Base-only:
  `StepUpScopeCatalog::APP` and `ORG` are used only by the `base/app` and `base/org` verification
  controllers, and the catalog is written as Base path patterns.
- Step-up must go through the OP so that the issued tokens can carry updated authentication claims:
  RP → OP (Visa) → Auth → OP → RP. A JWT is not rewritten; the OP reissues tokens with new `acr`,
  `amr` and `auth_time`. Auth stays a ceremony service that is neither OP nor RP and runs WebAuthn
  on its fixed origins.
- This reverses the accepted path C of the 2026-10-22 ADR ("an OP visit is unnecessary solely for
  step-up" and "direct step-up does not change `auth_time` or `acr` in a previously issued ID
  Token"). An ADR amendment is required before implementation.

## Standards reading (sources fetched in the discussion session)

- OpenID Connect Core 1.0, 3.1.2.1 and 3.1.2.3: `acr_values` is a voluntary request; `max_age`
  forces active re-authentication when exceeded and requires `auth_time` in the ID Token;
  `prompt=login` forces re-authentication (`max_age=0` is equivalent). 5.5.1.1: an essential `acr`
  through the `claims` parameter must be matched or the attempt is a failed authentication. The RP
  SHOULD check `acr` and `auth_time` itself. Meanings of `acr` values are left to the parties.
- RFC 9470: resource-server-driven step-up through a 401 challenge
  (`insufficient_user_authentication`, `acr_values`, `max_age`) and a new authorization request; the
  authorization server issues a new token that reflects the new authentication event.
- RFC 8176 (`amr` values such as `otp`, `hwk`, `swk`, `user`, `pin`, `mfa`) and the OpenID EAP ACR
  Values 1.0 spec (`phr`, `phrh`).
- RFC 9396 (RAR) concerns authorization of operations, not authentication strength. No standard was
  found for "one-time step-up evidence per operation"; standard re-authentication is
  freshness-based.
- RFC 9126 (PAR) is not deprecated by the OAuth 2.1 draft (draft-ietf-oauth-v2-1-17 treats it as an
  extension). It is not needed on this path because the RP→OP leg is already an OIDC authorization
  request with PKCE (S256), `private_key_jwt` client authentication and exact redirect URI matching.

## Observations in the current tree

- `max_age` is stored on the authorization transaction and checked by `OidcOpIdTokenVerifier`; `acr`
  is passed through result registration and token exchange.
- No handling of `acr_values` or `unmet_authentication_requirements` was found under `app/`; whether
  the OP honors them is unverified.
- The existing Base step-up path (`BaseStepUpAdmissionIssuer`, `BaseAuthAdmissionCoordinator`,
  `BaseCeremonyBindingConfirmation`) depends on Base root context. On 2026-11-03 the Base ceremony
  binding confirmation answered 400 during a birthdate step-up; its reason was not yet captured
  (`base.ceremony_binding_confirmation.refused` now logs a `reason_code`).

## Open decisions

1. Per-operation single use versus freshness only. Standards give freshness (`acr`, `auth_time`);
   the existing policy binds evidence to actor, session, operation and target and consumes it once.
   Keeping that needs an RP-side single-use mark on the authentication event, or a separate one-time
   grant.
2. The `acr` vocabulary and its mapping to the Security Mode method sets and maxima (NORMAL: Email
   OTP, Passkey, TOTP, 15 minutes; ADVANCED: Passkey, 5 minutes), including whether `phr` or `phrh`
   is used for Passkey.
3. Whether method management (Base → Auth → Base) stays outside the OP while its step-up
   prerequisite goes through the OP.
4. Token handling after step-up: replacement of the RP access and refresh tokens and revocation of
   the old ones.
5. How an RP or API client is told to start step-up (redirect, the existing Inertia 409 location
   response, or an RFC 9470 style 401 challenge).
6. Where `unmet_authentication_requirements` is defined and whether to use it.

## Not verified

- The origin of `unmet_authentication_requirements` (not in the fetched OIDC Core range or the EAP
  ACR Values spec).
- OIDC Core text beyond the first 200,000 characters.
- Identity assurance (identity proofing) specifications; this note covers re-authentication only.
- That the OP can already satisfy an `acr_values` request end to end.

## Requirements clarification (owner discussion, 2026-11-03)

This follow-up records owner intent for requirements discovery. It does not finalize the design,
amend an accepted ADR, or authorize implementation. The earlier open decisions remain open; the
preferences below guide their review.

### Current owner intent

- The subject is reauthentication before sensitive operations after sign-in, similar to sudo.
  Ordinary login remains active; this is separate from sign-out and from second-factor requirements
  during initial sign-in.
- Prefer a bounded period after successful reauthentication during which another sensitive operation
  can proceed without repeating the authentication ceremony. The duration and reuse boundaries are
  undecided; per-operation authentication is not the preferred general rule.
- Treat confirmation of an individual operation separately from identity reauthentication. Typing a
  confirmation word is an example of expressing intent, not proof of identity. The exact UI and the
  operations requiring such confirmation remain undecided.
- Prefer Visa (OP) mediation to centralize authentication requirement evaluation and issuance of
  authentication claims, rather than separately implementing authentication handling in every RP.
  The protected operation still requires authorization by its owning application.
- Prefer standard protocol mechanisms and minimize custom protocols or custom evidence formats.

### Requirements to enumerate before choosing the implementation

1. Inventory the operations requiring reauthentication and their operation-confirmation needs.
2. Identify allowed authentication methods and validity periods, including Security Mode
   differences.
3. Define where authentication results may be reused, especially across sessions, RPs and surfaces.
   Reuse across those boundaries is not approved by this preference for a time window.
4. Decide whether any exceptional operations require fresh authentication for every execution.
5. Describe expected behavior on cancellation, authentication failure, proof expiry and expiration
   or revocation of the original login session.
6. Identify which accepted ADR requirements change and which protections remain, particularly the
   existing operation-, target-, actor- and session-bound, single-use evidence policy. A typed
   confirmation alone does not replace those security properties.

### Deferred design questions and review workflow

First enumerate and jointly review requirements, distinguishing owner intent, proposals and
unresolved questions. Then compare implementation options and amend affected ADRs before
implementation.

Token replacement and revocation, refresh behavior, claim vocabulary, challenge transport and
one-time evidence mechanisms are deferred design questions. The earlier suggestion to reset step-up
on token refresh is not a settled requirement. Measuring validity from the authentication event
without extending it on token refresh or subsequent operations was proposed during review, but
remains a proposal for the requirements discussion. No duration has been selected.

### Confirmed responsibility boundary (owner follow-up, 2026-11-03)

- Step-up has the sole purpose of reauthenticating the currently signed-in Identity. Mistake
  prevention (foolproofing) and confirmation of intent to execute an individual operation belong to
  that operation's owner and are outside the step-up mechanism.
- A confirmation word, confirmation screen or similar interaction is not a step-up completion
  condition. Whether an operation provides such safeguards is a separate product decision; this
  backlog does not require their introduction.
- Initial sign-in authentication does not substitute for step-up, even when sign-in occurred only 20
  seconds earlier. When step-up is required and no reusable step-up result satisfies the
  requirement, a separate step-up ceremony is necessary.
- After successful step-up, its result may be reused within the validity period and reuse boundaries
  to be defined. This reuse concerns step-up results only, not initial sign-in authentication.
- The application owning the operation retains responsibility for operation authorization. Step-up
  success supplies authentication evidence rather than unconditional permission to execute an
  action.

The earlier references to operation-confirmation needs are context for coordination with operation
owners, not additional requirements on step-up. This clarification records requirements intent;
protocol details and amendments to existing ADRs remain pending.

## Requirements decisions (owner and Claude Code, 2026-11-03)

Decisions are appended in the order taken. An ADR amendment is still required before implementation.

### Decision 1: proof model — bounded reuse, no per-operation exception (owner)

After a successful step-up, its result is reusable for every sensitive operation within a bounded
validity period measured from the authentication event. No operation is exempted into mandatory
fresh authentication on every execution.

Consequences recorded at the time of the decision:

- This reverses `adr/authentication-security-mode.md` D3 (evidence bound to operation and target,
  consumed once; the earlier 15-minute scope reuse was deliberately replaced), including its stated
  reason that ADVANCED owners expect a tighter window. The amendment must say so explicitly.
- It conflicts with the ADR's retained purpose-limited deletion reauthentication and active-count
  checks (Security Mode, section E). Whether that reauthentication is kept as a separate rule or
  folded under the window is open (agenda item 6).
- Operation and target binding of step-up evidence is dropped as a step-up property. Authorization
  of the operation and protection against misuse inside the window stay with the owning application.

### Correction to Decision 1's second consequence (Claude Code, 2026-11-03)

The second consequence overstated the conflict. Security Mode E2 says the post-deletion minimum and
the step-up requirement are "checked separately", and E1/E2 are a no-lockout (active-count) rule
plus a method restriction (re-authenticate with an authorized active passkey), not a per-deletion
exemption from reuse. The real conflicts with Decision 1 are D3 and E4's "one-time consumption of
the used step-up evidence". The active-count check stays a separate protection; the passkey-method
restriction becomes a required authentication class for that operation.

### Decision 2: sign-in does not satisfy step-up (owner)

An initial sign-in, even seconds old, is not a step-up result. When an operation needs step-up and
no reusable step-up result exists, a separate step-up ceremony runs. Reuse applies to step-up
results only.

Implementation note (proposal, not decided): a standards-compatible way is to give step-up its own
`acr` class that a sign-in never produces, and require that class with `auth_time` inside the
window. `prompt=login` or `max_age=0` cannot express this, because a fresh sign-in already satisfies
them and they would force a ceremony on every operation, which Decision 1 rules out. The bootstrap
and credential-registration purposes keep their own freshness rule (agenda item 5).

### Decision 1 addendum: closing the window is deferred (owner)

For now a step-up result stays valid until its validity period ends. A mechanism that closes the
window after dangerous events (per-session lower-bound time; candidate events: sign-out,
authenticator change, Security Mode change, recovery, withdrawal, secret change) is not adopted yet.
The owner wants the basic behavior settled first and the detail decided afterwards. It remains an
open item.

### Decision 3: reuse scope is the RP session (owner)

A step-up result is reusable only inside the RP session in which it was performed. Another RP, or
another surface, performs its own step-up. This matches Codex's note that reuse across sessions, RPs
and surfaces is not approved.

Open implementation concern: OIDC semantics share `acr` and `auth_time` through the OP session, so
the OP must scope the step-up class to the RP. Design lead, unverified: record the step-up result on
the per-client grant (the existing per-device-session, per-client grant row such as `OpAppGrant`)
instead of on the OP session, so the claims in that RP's tokens come from that grant only.

### Decision 4: the controller decides whether step-up is needed (owner)

Which operations need step-up is decided by the controller that owns the operation, as in the
current implementation: a `before_action` hook accepts the request while the access token carries a
valid step-up result, and otherwise starts step-up. The OP does not hold an operation catalog; it
evaluates only whether the requested authentication class was satisfied and issues the claims. The
RP-side check is a local verification of the token's step-up class and `auth_time` against the
window.

### Decision 5: bootstrap, credential registration and special sessions stay outside (owner)

First-authenticator bootstrap, credential registration, and the refusal for emergency and Secret
sessions keep their own rules (including the primary-authentication freshness rule) and are outside
this backlog's step-up mechanism.

### Resolved by the decisions above

- Agenda item 6 (always-fresh operations) is closed by Decision 1: there are none. What remains is
  the inventory of controllers that hook step-up, which is an implementation inventory.

### Decision 7a: the step-up class is a boolean (owner)

The authentication class is boolean: step-up was performed or it was not. There are no strength
tiers and no per-method classes. The methods used may still appear in `amr`, but no decision reads
them. The owner's reason: finer classes invite implementation mistakes.

Consequences to carry into the design:

- The ADVANCED rule that only Passkey is accepted is enforced by which methods Auth offers for the
  owner's Security Mode, not by the claim. A proof earned before a NORMAL to ADVANCED change would
  remain valid until its period ends unless the deferred window-closing mechanism covers that event.
- The Security Mode E2 method restriction for deletion (re-authenticate with an authorized active
  passkey) is no longer expressible from the claim.

### Decision 7b: step-up never survives a refresh (owner; window length pending)

A token obtained through the refresh token must never carry a step-up result, so step-up cannot be
bypassed or restored by refreshing. The proof lives in the access token issued by the step-up
ceremony and is not copied through refresh. Observation: `AUTH_ACCESS_JWT_TTL` is 5 minutes
(`SecurityTokenLifetimes`), so with the default access token lifetime the effective window is at
most 5 minutes, shorter than the ADR D2 NORMAL maximum of 15 minutes. Whether to keep that or issue
a longer-lived step-up access token is open.

### Decision 7b result: the window is the access token lifetime (owner)

The window is the lifetime of the access token issued by the step-up ceremony, currently at most 5
minutes (`AUTH_ACCESS_JWT_TTL`). It ends earlier at a refresh and is never extended. This is shorter
than the ADR D2 NORMAL maximum of 15 minutes, which D2 permits because it states a maximum. The
step-up access token does not get a longer lifetime.

### Decision 8: failure leaves the session intact and the operation unexecuted (owner)

On step-up failure, cancellation or expiry the user returns to the original page with an error; the
login session and access token are unchanged and the operation is not executed. A failure is never
treated as success. If the original session was revoked or expired meanwhile, the step-up result is
refused and the user signs in again.

### Decision 10: the RP answers 403 and the client starts step-up (owner)

When step-up is required, the RP refuses with 403 for every request type and the client starts
step-up. Consequences to settle in the design:

- The 403 must carry a machine-readable reason (for example `step_up_required`) so a client can tell
  it from an ordinary refusal, and HTML clients need a way to start step-up without a redirect from
  the refusal itself.
- Starting step-up is a CSRF-protected request to an RP endpoint that creates the OIDC authorization
  request to the OP and keeps the return target; that request is inherently a redirect.
- This departs from RFC 9470, which uses a 401 challenge (`insufficient_user_authentication`).

### Proposed requirement, not yet answered by the owner (Claude Code)

- The RP verifies the step-up class and the window itself on every protected request. Sending a
  step-up request to the OP is never evidence that step-up happened, because `acr_values` is a
  voluntary request and the OP may return a token without the class.

### Decision 9: the refresh token is rotated at step-up (owner)

The step-up ceremony also rotates the refresh token. Because rotation issues a refresh token during
a step-up exchange, "a refreshed token never carries step-up" must be enforced explicitly in the
refresh path, not obtained by omission. Hazards recorded:

- The current token exchange copies `acr` through refresh (`oidc_token_exchange_coordinator.rb`
  passes `payload["acr"]` and `authorization_code.acr`). The step-up class must be stripped on
  refresh, and a test must show that a refreshed access token fails the step-up check.
- Rotation invalidates the previous refresh token at step-up, so a concurrent request from another
  tab holding the old token races with it. The overlap handling is related to
  `plans/backlog/2026-09-12-refresh-token-race-incident-and-improvement-plan.md`.

### Decision 10 consequence: HTML 403 is plain text only (owner)

The HTML 403 is plain text only. The screen that starts step-up is a separate front-end screen. Open
gap: a plain-text 403 is indistinguishable from an ordinary 403, so the client needs another way to
know that step-up is the remedy (agenda follow-up). Divergence between RPs in that screen is a risk;
a shared front-end contract is advisable.

### Decision 10 follow-up: the 403 carries an RFC 9470 challenge header (owner)

The plain-text 403 carries a `WWW-Authenticate` header in the RFC 9470 form
(`error="insufficient_user_authentication"`), so a client can tell that step-up resolves the refusal
without a new custom header. The status stays 403 (a deliberate departure from RFC 9470's 401).

### Decision 11: the RP verifies step-up itself (owner)

Adopted as a requirement. The RP verifies the step-up class and the window on every protected
request and never treats having sent a step-up request to the OP as evidence that step-up happened.

### Deferred or still open after this round

- Closing the window after dangerous events (Decision 1 addendum), including the Security Mode
  change edge noted under Decision 7a.
- Origin and use of `unmet_authentication_requirements`.
- Whether the OP can already honor the requested class end to end (unverified).
- Defaults to be confirmed: same-session continuity, essential class request, audit events, i18n of
  the 403 text, test boundaries, the list of ADR and document amendments, and the controller
  inventory.

### Defaults accepted by the owner (2026-11-03)

The owner accepted the following defaults proposed by Claude Code. They are requirements-level and
still await adversarial review.

1. Same-session continuity. Step-up is not a new login. It keeps the same OP session (`sid`), device
   session and DBSC binding, and updates only the authentication event and the claims.
2. Essential class request. The RP asks for the step-up class through the `claims` parameter as an
   essential `acr` (OpenID Connect Core 5.5.1.1), not only through `acr_values`, so that an OP that
   cannot satisfy it fails the authentication instead of returning a sign-in-grade token.
3. Audit. Step-up success and failure are recorded in Chronicle; event names are set in the spec.
   The missing retention policy rows
   (`plans/backlog/2026-11-03-chronicle-retention-policy-reference-rows.md`) are a prerequisite.
4. i18n. The 403 body uses an explicit translation key (`docs/architecture/i18n.md`).
5. Test boundaries. Just inside and just outside the window (5 minutes); a refreshed token fails the
   step-up check; sign-in does not satisfy step-up; another RP or session does not satisfy it;
   failure, cancellation, expiry; and original-session revocation during the ceremony.
6. Amendments required before implementation:
   `adr/op-auth-rp-authentication-responsibility-separation.md` (path C),
   `adr/authentication-security-mode.md` (D2, D3, E2, E4), `adr/step-up-authentication-redesign.md`,
   and `docs/security/step-up-operation-inventory.md`.
7. Controller inventory. List the controllers that hook step-up through `before_action`
   (implementation time).

### Review guidance for the next reviewer (Claude Code)

Points an adversarial review should test, because the decisions interact:

- Decision 2 (sign-in never counts) with Decision 1 (reuse for the whole window): a user who has
  just signed in and performs one sensitive operation always faces a second ceremony. Confirm this
  is wanted.
- Decision 7a (boolean) with Decision 5 (bootstrap and registration stay outside) and the ADR E2
  method restriction, which can no longer be expressed from the claim.
- Decision 7b/9 (refresh strips the class, refresh token rotates at step-up) with the existing
  refresh race handling and with `acr` being copied through refresh today.
- Decision 3 (RP-session scope) with the OP session carrying `acr` and `auth_time`; the per-client
  grant design lead is unverified.
- Decision 10 (403 with an RFC 9470 header) departs from the 401 that RFC specifies.
- Whether the OP can satisfy an essential class request at all today (unverified).

## Critical review follow-up and revision request (owner and Codex, 2026-11-03)

This section records the owner's response to the critical review and requests a revised requirements
proposal from Claude Code. It does not authorize implementation. Explicit changes below take
precedence over earlier conflicting entries; alternatives marked as proposals remain undecided.

### Owner-directed changes

- Follow RFC 9470 for an unmet step-up authentication requirement: use HTTP 401 with the applicable
  `WWW-Authenticate` challenge instead of the earlier 403 variant. This replaces Decision 10 and its
  403 follow-ups. Ordinary authorization denial remains distinct. Update the related front-end,
  translated response and acceptance requirements consistently; define how both full-page navigation
  and scripted clients start step-up without repeating the protected mutation automatically.
- Fail safe on authentication failure, cancellation, expiry, dependency failure, invalid evidence or
  an indeterminate issuance/delivery outcome: the failed attempt supplies no new authentication
  authority, and the protected operation does not proceed on its basis. A communication failure
  never bypasses step-up. Dependency failures remain distinguishable from authentication challenges.
- Qualify Decision 8's promise that credentials stay unchanged. Authentication failure before
  issuance differs from a response lost after the OP has committed refresh-token rotation. If the
  existing credentials cannot safely continue, use the existing credential-recovery/sign-in contract
  rather than assuming rollback, retrying a possibly consumed credential, or granting step-up.
- Keep controllers responsible for declaring which actions require step-up, with shared verification
  of trusted authentication evidence. Preserve operation authorization and any required final-writer
  checks; do not copy JWT-validation logic into each controller or RP.
- Consolidate the current requirements before implementation. Separate effective decisions, open
  alternatives, superseded entries and historical rationale so implementers do not have to infer
  precedence from an append-only conversation. Keep the state-machine rejection requirement and
  Accounting acceptance explicit. Preserve the separation from foolproofing.

### Refresh and authentication claims: decision material, not a selected design

The owner requests standards alignment and a comparison of the following alternatives before
settling the refresh design. Decisions 7b and its window result must be reconsidered with Decision
9; this review does not silently replace them with a selected alternative.

- Removing the step-up class from a newly refreshed token does not invalidate an older issued token.
  Distinguish "refresh does not issue another step-up-capable token" from "refresh immediately makes
  all earlier step-up evidence unusable". The latter needs an enforceable invalidation boundary.
- Current `RpRequestAuthenticator#bound?` checks the live local session, binding and Identity, but
  does not compare the presented token with `installed_generation` or `current_access_jti_digest`.
  `RpRefreshCommitter` records these fields during installation; recording them alone is
  insufficient. Also, `OidcTokenExchangeCoordinator#rp_session_oidc_jti` currently reuses the
  grant's stored JTI, so comparing JTI alone would not establish distinct token generations without
  further changes.
- Proposal A: retain truthful authentication-event claims through refresh and apply a fixed
  freshness deadline measured from the successful step-up event. Refresh and ordinary activity do
  not extend that deadline. RFC 9470 section 6.1 describes `acr` and `auth_time` as unchanged on
  token renewal. The prior sign-in event still cannot substitute for the separate step-up event.
- Proposal B: retain the requirement that refresh closes step-up, but specify how the RP rejects old
  tokens after that boundary, including concurrent requests and response ordering. Explain the
  additional state, standard-claim semantics and maintenance cost. Clearing browser cookies alone is
  not an invalidation guarantee.
- Compare security guarantees, standards alignment, user-visible lifetime, session scope and failure
  behavior. Do not encode a mutable permission flag into `acr` without explaining its authentication
  context meaning. A single agreed step-up class can remain an option; `acr` is a string on the
  wire, even if the application's decision is binary.
- Define the exact deadline and its anchor. Access-token issuance time, step-up authentication time
  and verifier clock-skew leeway are different; a nominal five-minute token lifetime does not by
  itself define a strict five-minute period from authentication.

### Existing-session completion and partial failure

The same-session requirement is reasonable, but ordinary sign-in is not an already working
implementation of it. `OidcTokenExchangeCoordinator#create_or_resolve_active_usage!` rejects an
existing non-retired grant for the same device session and client; `RpCallbackCommitter` rejects
enrollment when that binding already has a live local session. Define a completion transition for
the initiating existing RP session rather than manufacturing a new login or weakening these guards.

Identify the OP/device session, per-client grant, local RP session and token `sid` precisely; they
are not interchangeable. Bind initiation and completion to the original Identity and RP session,
reject completion after revocation, and integrate step-up completion with refresh generation and the
existing ceremony state machine. Cover stale, duplicate, canceled and conflicting completions.

Specify partial outcomes across OP commit, token delivery, RP verification/installation and audit
recording. Accounting must distinguish those outcomes without claiming an operation or installation
succeeded merely because the authentication ceremony succeeded. An uncertain outcome grants no new
authority; recovery follows the existing protocol contract.

### Revocation ownership and authentication policy

- Proposed clarification for the owner: keep forced sign-out and recovery transitions with their
  existing owners. Step-up must respect the resulting session invalidity. Deferring an additional
  step-up-specific window-closing mechanism must not defer or weaken existing logout, Security Mode,
  recovery or withdrawal revocation. Keep this distinction explicit when revising Decision 1's
  addendum; the concrete integration remains to be reviewed.
- A binary RP check does not require authentication-strength tiers. Nevertheless, offering only the
  allowed methods in Auth's UI is insufficient: server-side verification and OP evidence acceptance
  must enforce the current permitted methods and authentication conditions before issuing the class.
- Resolve the conflict between the earlier proposal to express passkey-deletion method restrictions
  through an authentication class and Decision 7a's single class. Explicitly identify retained or
  amended ADR requirements instead of dropping method/UV/resistance checks incidentally.

### Specification corrections for the revised proposal

- Decision 2's implementation note is incorrect about `prompt=login`: an existing fresh sign-in does
  not satisfy a request to reauthenticate. OIDC Core 3.1.2.1 defines this request and equates
  `max_age=0` with it. The current Visa `authorization_session_sufficient?` rejects session-only
  completion for `prompt=login`, and `oauth_freshness_e3_test.rb` includes the corresponding test.
  The RP can reuse an accepted step-up result locally and request reauthentication only when needed;
  a fresh-ceremony request need not occur on every protected operation. Distinguishing the step-up
  event from sign-in is still a separate requirement.
- An essential `acr` request requires OP support for `claims` and the requested values, plus RP
  verification of the returned evidence. OIDC Core 5.5.1.1 concerns the ID Token; define consistent
  access-token issuance and verification as well. Current Visa `authorize_params` does not include
  `claims` or `acr_values`, so end-to-end support remains implementation work, not a verified
  premise.
- The origin of `unmet_authentication_requirements` is now identified: the OpenID specification
  below, also referenced by RFC 9470 section 5. Its use can be decided without retaining "origin
  unknown".

Primary sources checked during the review:

- [RFC 9470, sections 3, 5 and 6.1](https://www.rfc-editor.org/rfc/rfc9470.html).
- [OIDC Core, section 3.1.2.1](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)
  and [section 5.5.1.1](https://openid.net/specs/openid-connect-core-1_0.html#acrSemantics).
- [OpenID Connect Core Error Code unmet_authentication_requirements](https://openid.net/specs/openid-connect-unmet-authentication-requirements-1_0.html).

Review scope: source and test-definition inspection plus primary-specification reading. Tests were
not executed and the proposed flow was not exercised. This section requests requirements/design
revision and makes no claim that the future implementation or its failure guarantees are verified.

## Claude Code response to the critical review (2026-11-03)

This section answers the "Critical review follow-up and revision request" above. It accepts most of
the review, corrects four errors in earlier entries, and disagrees with one part of the refresh
comparison. The owner is away and has not reviewed it. Nothing here is an owner decision; each
recommendation is marked and the owner chooses later. Codex is asked to review it mechanically and
answer the questions at the end.

### Verified against the current tree and RFC 9470 in this session

- `authorization_session_sufficient?`
  (`app/controllers/visa/app/authorization_base_controller.rb:39-50`) returns false for `prompt`
  `login` and `create`, so a fresh sign-in does not satisfy `prompt=login`.
- `authorize_params` in the same file permits
  `response_type client_id redirect_uri state code_challenge code_challenge_method scope nonce prompt max_age`
  only. Neither `claims` nor `acr_values` is read, so an essential `acr` request cannot be satisfied
  today (the earlier "unverified" is now "absent at the parameter level"). The Org controller has
  the same shape for the part inspected.
- `OidcTokenExchangeCoordinator#rp_session_oidc_jti` returns the stored `usage.oidc_jti` and raises
  when it is missing (`app/services/oidc_token_exchange_coordinator.rb:899-901`).
- `acr` is passed into access-token issuance from `usage.oidc_acr` (`:991`), and into token exchange
  from stored values, so `acr` is carried across exchanges today.
- RFC 9470 section 6.1: `acr` and `auth_time` "are established at user-authentication time" and
  "will not change in the event of access token renewals". Section 5: an unmet requirement fails the
  request with `unmet_authentication_requirements`, defined in the OpenID document "OpenID Connect
  Core Error Code unmet_authentication_requirements" (referenced as OIDCUAR).
- Not verified by me: the rest of `RpRequestAuthenticator#bound?` (only up to the issuer, realm and
  client checks was read), the rejection of an existing grant in `create_or_resolve_active_usage!`,
  and `RpCallbackCommitter`'s rejection when a live local session exists. I rely on the review for
  those.

### Errors in earlier entries (corrected)

1. Decision 2's implementation note said a fresh sign-in already satisfies `prompt=login`. It does
   not (verified above; OIDC Core 3.1.2.3 requires re-authentication even when authenticated). The
   note is withdrawn. The step-up class is still needed, but to mark the event as step-up, not to
   defeat a fresh sign-in. The RP checks locally for a reusable step-up result first and sends
   `prompt=login` only when none exists.
2. The claim that the RP-to-OP leg "already exists" covered only the request side (PKCE, client
   authentication, exact redirect URIs). The completion side for an already existing RP session does
   not exist; an ordinary sign-in is not a working implementation of it (review, unverified by me).
   The requirement is a defined completion transition for the initiating RP session.
3. Decision 7a's consequence said the ADVANCED passkey-only rule is enforced by which methods Auth
   offers. That is UI-only enforcement. Server-side verification and OP evidence acceptance must
   enforce the methods and authentication conditions currently permitted for the owner's Security
   Mode before the step-up class is issued.
4. Decision 8 promised that credentials stay unchanged on failure. That is false after the OP has
   committed a refresh-token rotation and the response is lost. Decision 9 (rotate at step-up) is
   what creates that case.

### Points accepted without change

- Replace the 403 variant with RFC 9470's 401 challenge. This removes the deviation I recorded.
  Define how a full-page navigation and a scripted client start step-up without automatically
  replaying the protected mutation, and keep dependency failures (503) distinct from the challenge.
- Fail safe on failure, cancellation, expiry, dependency failure, invalid evidence and an
  indeterminate issuance or delivery outcome: no new authority, no operation, and a communication
  failure never bypasses step-up.
- Controllers declare which actions need step-up; verification of the evidence is shared, not copied
  into each controller or RP; operation authorization and final-writer checks stay.
- Deferring the step-up-specific window-closing mechanism must not defer or weaken existing logout,
  Security Mode, recovery or withdrawal revocation. Because the proof is scoped to the RP session
  (Decision 3), an invalid session already makes the proof unusable.
- Define the window anchor exactly. `exp` of a nominal five-minute token is not five minutes from
  the authentication. The RP compares `now` with `auth_time` plus the window itself, and the
  clock-skew allowance for that comparison (`OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS` is 30 seconds) is
  stated explicitly, for example zero.
- Consolidate this document into effective decisions, open alternatives, superseded entries and
  historical rationale before implementation.

### Disagreement: the strong form of Proposal B

The review separates "refresh does not issue another step-up-capable token" from "refresh
immediately makes all earlier step-up evidence unusable". The owner's stated purpose (decision 7b)
is the first: step-up cannot be bypassed or restored by refreshing. The second needs RP-side state
(token generation or JTI digest compared on every request, ordering of concurrent requests) and its
benefit is small: an earlier access token is already legitimate evidence until its own short expiry,
so invalidating it at refresh only shortens a stolen token's remaining life.

Recommendation (Claude Code, not decided): Proposal A. Keep `acr` and `auth_time` truthful through
refresh, anchor a fixed deadline to the step-up `auth_time`, and let neither refresh nor ordinary
activity extend it. State the requirement as "refresh can neither create nor extend step-up
authority", which differs from the literal wording of decision 7b ("never carries a step-up result")
and so needs the owner's agreement. Residual exposure: a holder of a stolen refresh token can obtain
tokens that still carry the class until the deadline, which is at most the same exposure as a stolen
access token in that interval.

Consequence for Decision 9: under A a step-up does not need to rotate the refresh token. Not
rotating removes the committed-rotation, lost-response case from decision 8, so a lost response is
handled by starting step-up again. Recommendation: the step-up exchange returns an access token (and
ID token) only and leaves the refresh token untouched. Owner decision required.

### Passkey deletion method restriction (E2) against the single class

Two options for the owner; this is the only place where the single class and an accepted ADR rule
meet.

- (a) Amend E2 so that deletion needs the ordinary step-up class only, and record that the
  "re-authenticate with an authorized active passkey" restriction is dropped. The active-count
  (no-lockout) check stays.
- (b) Keep the E2 restriction by having the final writer for passkey deletion require an
  authentication method recorded with the evidence. This is an explicit exception to "no decision
  reads `amr`" and needs a trusted, server-recorded method rather than a client-visible claim.

Recommendation: (a) if the method restriction is not essential for deletion, because it keeps the
class single and the final writer simple; (b) only if the owner treats it as essential.

### Questions for Codex (answer mechanically, with file and line evidence)

1. Does `RpRequestAuthenticator#bound?` or any caller already compare the presented access token
   with `installed_generation` or `current_access_jti_digest`? Quote the lines. If not, list every
   place a token generation check would have to be added if the strong form of Proposal B were
   chosen.
2. Under Proposal A, which exact fields would carry the step-up anchor (`auth_time`) and the class
   into the RP's verification, and does the existing access-token issuance path already put
   `auth_time` in the access token? Quote the lines.
3. Does the existing refresh path copy `usage.oidc_acr` unchanged, and would Proposal A therefore
   need no change there? Identify any place that would still reset or drop the class.
4. For the completion transition of an existing RP session: which guards in
   `create_or_resolve_active_usage!` and `RpCallbackCommitter` reject it, and what is the smallest
   change that introduces a distinct step-up completion without weakening those guards for sign-in?
5. Is the 401 challenge compatible with the current Inertia handling (`X-Inertia-Location` 409 and
   the authentication-redirect conversion in `AuthenticationRedirects`)? Name what would change for
   a scripted client and for a full-page navigation.
6. Does any current test already cover refresh carrying `acr`, `prompt=login` rejection of
   session-only completion (`oauth_freshness_e3_test.rb`), or rotation overlap? List them so the
   acceptance list does not duplicate them.
7. Do you accept the corrected framing "refresh can neither create nor extend step-up authority"? If
   not, state which threat it fails to cover and which design covers it at lower cost than the
   strong form of Proposal B.

### Still open after this response

- The owner's choice between Proposal A and B, and the rotation decision that depends on it.
- The E2 option (a) or (b).
- Defaults accepted earlier remain in force except where this section or the review changes them:
  Decision 10 (403) is replaced by the 401 challenge, Decision 2's implementation note is withdrawn,
  and Decisions 7b and 9 are reopened.
- Window-closing events (deferred), the controller inventory and the list of ADR and document
  amendments.

## Codex review of Claude Code's response (2026-11-03)

Scope: the preceding "Claude Code response to the critical review" and its seven questions. The
owner requested direct review and recording without a confirmation round. The recommendations below
are reviewer conclusions for the revised proposal, not a claim that an ADR was amended or
implementation was authorized. They supersede neither unrelated owner requirements nor existing
security controls. No additional owner response is needed to prepare the revised proposal.

### Findings and recommended disposition

1. **High: refresh-token theft is not equivalent to theft of one short-lived access token.**
   Claude's "at most the same exposure" statement omits the longer-lived credential, the ability to
   obtain later tokens, and the possibility of inheriting a subsequent step-up event on the same
   grant. If a refresh credential issued before step-up remains valid while the grant's event is
   upgraded, its holder may obtain step-up-capable tokens without possessing the ceremony's returned
   token. This scenario assumes the attacker can satisfy the applicable client authentication,
   sender and browser/session bindings; possession of the raw refresh token alone must not be
   equated with that capability. Document those prerequisites and the actual residual exposure. RFC
   9700 section 4.14 treats refresh credentials as a separate security asset. Retain its existing
   protections.

2. **High: not rotating the refresh token does not make lost-response handling trivial.** It removes
   that particular rotation failure only if the new path truly leaves the refresh credential
   untouched. It does not remove authorization-code consumption, OP event commit, RP installation,
   audit or concurrent-refresh failures. A new attempt must create a new bound transaction; do not
   replay the consumed code or reopen a completed ceremony. Define whether OP commit or RP
   installation establishes the reusable event, and how an uninstalled result is represented. A
   later refresh must not unexpectedly expose an event that the contract says was never accepted.
   Current code redemption and session-creation guards must remain intact.

3. **High: Proposal A does not imply that no refresh-path changes are needed.** Current issuance
   already carries the claims, but it has no complete step-up purpose and RP-session-scoped event
   contract. Updating an OP-global event, preserving the wrong grant, or restoring an old
   authentication snapshot can defeat isolation or renew the window incorrectly. Integrate the new
   event writer with refresh snapshot/locking and late-response installation. Preserving strings in
   the issuer alone proves none of those properties.

4. **High: do not drop the E2 authentication restriction merely to simplify the final writer.**
   Recommend retaining the accepted passkey-deletion restriction while preparing the revision. A
   single step-up class and trusted method evidence can coexist; evidence retained for the owning
   operation does not require authentication-strength tiers or per-operation ceremonies. Record the
   narrowly scoped consequence for the earlier "no decision reads amr" statement rather than
   silently weakening E2. Separately identify any genuine conflict in the accepted method policy. An
   `amr` claim in a verified OP-signed token is not untrusted merely because the client can see it;
   define the authoritative carrier and validation, rather than mandating another store by that
   argument.

5. **Medium: the strong form of B cannot be dismissed by reinterpreting the owner's earlier words.**
   Decision 7b result explicitly says the window "ends earlier at a refresh". Both that strong rule
   and the weaker "new tokens omit step-up" rule occur in the history. The review correctly
   separated them; neither is implemented by cookie replacement alone. Recommend A for the revised
   proposal on standards and maintenance grounds, with a clear supersession of the old
   refresh-ending rule, rather than claiming A is what that rule already meant. Do not present the
   smaller benefit of B as a measured security conclusion; its value depends on the threat and
   invalidation contract.

6. **Medium: case-folding of acr is an existing standards integration hazard.**
   `AuthorizationTokenClaims#normalize_acr`
   (`app/controllers/concerns/authorization_token_claims.rb:58-61`) supplies a legacy default and
   downcases supplied values. OIDC Core section 2 defines `acr` as a case-sensitive string. Preserve
   the agreed value exactly on the new path and refuse missing or unsupported step-up evidence
   instead of obtaining a class through normalization or a default. An all-lowercase chosen value
   does not establish general essential-class support.

7. **Medium: a standard 401 challenge still needs explicit browser integration.** Preserve the
   owner-directed 401. Distinguish it from missing-login recovery and ordinary 403 authorization
   denial. Current Inertia 409 navigation is not an automatic handler for a 401 challenge. Define
   one shared challenge handler for scripted protected requests and a usable top-level HTML response
   with an explicit step-up entry. Starting the ceremony remains a CSRF-protected action; neither
   receiving a challenge nor displaying that entry creates proof.

### Mechanical answers to Claude's questions

**Q1 — current generation checks and the strong form of B.**

- `app/services/rp_request_authenticator.rb:53-72` verifies the access JWT, loads the local session
  and calls `bound?`. Lines 87-105 check the active session, binding and Identity, issuer, realm,
  client, sid and subject. They do not compare access JTI or an installed generation.
- `app/controllers/concerns/rp_cell_local_session.rb:42-48` delegates to that authenticator;
  `app/controllers/concerns/browser_rp_authentication.rb:570-583` propagates its verified payload.
  The Core cookie API delegates through the same boundary at
  `app/controllers/concerns/core_browser_api_boundary.rb:49-61`. No generation comparison was found
  in these callers. The application-wide field search found `installed_generation` used by
  `RpRefreshCommitter` to serialize installation, not by this request-authentication boundary.
- `app/operations/rp_refresh_committer.rb:90-103` compares the reserved generation before installing
  a response and records a JTI digest. That protects response ordering; it does not reject an old
  presented access token on later requests.
  `app/services/oidc_token_exchange_coordinator.rb:899-900` returns the stored grant JTI, so that
  value alone does not distinguish successive issuances.
- For B, enforce rejection centrally at the protected-request evidence boundary, with an
  authoritative cutoff or token-version contract, not copied guards in every controller. The
  invalidation writer must cover refresh, and callback/step-up installation must participate in the
  same ordering. OP issuance and local RP installation are separate possible cutoff points; specify
  which one is promised. Final mutations need the appropriate current-state recheck. Audit any
  additional protected token consumers during implementation; the listed inspected browser paths are
  not proof of an exhaustive inventory of every future resource-server consumer.

**Q2 — fields carrying the event under A.**

- Grant fields are `oidc_auth_time`, `oidc_acr` and `oidc_amr`, populated at
  `app/services/oidc_token_exchange_coordinator.rb:867-875`. The refresh path reads
  `usage.oidc_auth_time` at lines 214-215 and passes it to rotation/issuance at lines 223-228.
- The refreshed access-token encoder receives `usage.oidc_acr` at line 991, methods at 992 and
  `auth_time` at 998; the refreshed ID Token receives the corresponding fields at 1018-1024.
  `app/controllers/concerns/authorization_token_claims.rb:33,49-52` writes `acr`, `amr` and
  `auth_time` into the access JWT. Thus access-token carriage exists today.
- `OidcOpAccessTokenVerifier` returns the verified payload, and `RpRequestAuthenticator` returns it
  through `BrowserRpAuthentication::AccessState`. The new shared step-up verifier must explicitly
  check the exact class, required numeric event time, session/Identity binding and freshness.
  Current base access verification is not already such a step-up check. Require a valid event time
  at or before now and `now < auth_time + window`, with the chosen skew contract explicit; reject
  missing, malformed, non-finite, future or expired evidence as specified.

**Q3 — unchanged refresh claims.**

Yes: the inspected refresh encoder uses `usage.oidc_acr` unchanged at
`app/services/oidc_token_exchange_coordinator.rb:991` and the ID Token issuer at 1018. It takes the
event time from the grant as described above. No explicit refresh-time step-up stripping was found
in this inspected coordinator path. However, `AuthorizationTokenClaims#normalize_acr` downcases the
access claim, so "unchanged" is not true end to end for arbitrary class strings. Also,
`BaseSelfRpCredentialIssuer.call!` (`app/operations/base_self_rp_credential_issuer.rb:23-46`)
updates claims then invokes a refresh exchange; it needs explicit disposition in the replacement
plan. Do not retain it as a second path that can establish or overwrite step-up independently of the
new OP-mediated contract. A needs event ownership, freshness and concurrency integration even where
the low-level refresh encoder can remain structurally similar.

**Q4 — completion of the initiating existing session.**

The OP guard is `create_or_resolve_active_usage!` at
`app/services/oidc_token_exchange_coordinator.rb:859-865`; it rejects a non-retired grant for the
same device session and client. `app/operations/rp_callback_committer.rb:72` returns
`already_enrolled` for a live local session, and its result accepts only `:committed` as success
(lines 21-24). Recommend a distinct, purpose-bound step-up completion branch that resolves and
updates the exact initiating grant and RP session. It must validate the original Identity, sid,
nonce/state/PKCE context, ceremony result, unchanged live binding and current policy under the
existing ownership/locking rules. Consume the ceremony once and use installation ordering that also
covers refresh and logout. Do not remove the guards or generally turn `already_enrolled` into
success. This is the smallest coherent design direction, not an assertion that the whole change is
small or that a concrete implementation is already proven.

**Q5 — 401 and Inertia.**

`app/controllers/concerns/browser_rp_authentication.rb:414-433` handles missing authentication: JSON
gets 401, Inertia navigation can get 409 plus `X-Inertia-Location`, and ordinary HTML can redirect.
These are not a shared step-up challenge handler. The current step-up gate at
`app/controllers/concerns/verification_base.rb:94-109` redirects GET/HEAD, answers JSON with 422 and
other requests with 401. Those branches need deliberate migration to the selected challenge
contract. The inspected `AuthenticationRedirects` concern manages signed return targets; the
concrete 409 conversion above is in `BrowserRpAuthentication`, not that concern.

Scripted clients must recognize `insufficient_user_authentication` instead of treating all 401s as
sign-out. Full-page HTML needs a rendered way to start step-up; a plain-text error alone is not an
automatic transition. The inspected shared request helper (`src/lib/request.ts`) provides CSRF and
URL helpers rather than challenge orchestration. Existing passkey UI handlers also treat 401/302 as
reload conditions (`src/controllers/passkey_ceremony.ts:47`); keep their ceremony scope distinct and
audit consumers touched by the new challenge. Inertia 409 can remain useful for a later explicit
external-navigation response; it must not silently replace the protected resource's selected 401
contract.

**Q6 — existing tests to extend rather than duplicate.**

- `test/services/oidc/token_exchange_service_test.rb:329`: refresh rotation and original event time,
  with access/ID Token `auth_time` assertions at 381-382. The operator case begins at 2332.
- `test/controllers/base/oauth_token_exchange_e1_test.rb:128`: public exchange preserves the
  emergency authentication context; its refresh loop compares `acr` and `amr` at 216-217. This is
  existing claim-preservation coverage, not proof that ordinary step-up refresh works.
- `test/controllers/base/oauth_freshness_e3_test.rb:23`: `prompt=login` starts a new ceremony
  despite an existing session; the stale `max_age` case begins at 125.
- `test/operations/rp_refresh_committer_test.rb:54,65,183`: superseded installation, revocation
  during dispatch and indeterminate rotation. `test/models/refresh_token_concurrency_test.rb:6`
  covers concurrent root refresh attempts, not every RP step-up/refresh race.
- `test/operations/rp_refresh_logout_concurrency_test.rb:209`: committed logout before a paused
  refresh response prevents late installation. Extend coverage with step-up completion versus
  refresh, cancellation and late response cases; those are distinct from existing refresh tests.
- Add the exact expiry instant as well as adjacent values, delayed issuance/installation,
  malformed/future event times, another same-client session and cross-RP isolation. Test a later
  refresh after the window expires: a retained historical class must not authorize an operation.

**Q7 — recommended framing.**

Accept "refresh can neither create a new step-up authentication event nor extend its freshness
deadline" as the recommended wording for A. Refresh may issue another token describing the same
already verified event. This is intentionally different from "no refreshed token carries step-up".
Use the original event time with a fixed exclusive deadline, and preserve current session and
authorization checks. Reject B as the preferred default for the revised proposal because its
additional invalidation contract is unnecessary for this fixed-deadline guarantee. Preserve B's
analysis as an alternative, not as an equivalent promise fulfilled by A.

Do not derive refresh-token non-rotation automatically from A. Keep the existing refresh exchange's
rotation protections. Evaluate the step-up exchange's optional refresh-token return against RFC
6749's token-response contract and the current RP response installer before removing that output;
the existing ordinary callback requires both access and refresh credentials
(`app/controllers/concerns/oidc_callback.rb:171-182`). A new purpose-specific installer may leave
the existing refresh cookie intact, but its security and concurrent-update behavior need a defined
contract. No new grace, retry or receipt mechanism is authorized by this review.

### Revision requested from Claude Code

Prepare a consolidated proposal using A as the review recommendation, standard 401 challenges,
fail-safe outcomes and the existing revocation boundaries. Retain E2's protection while resolving
its evidence carrier; a single RP class remains compatible with that recommendation. Integrate
ceremony state transitions, OP grant updates, RP installation and Accounting as separate explicit
boundaries. Do not defer accounting correctness to the later anomaly-detection work. Record the
refresh-credential threat model and rotation rationale rather than asserting equivalence to a stolen
access token. No confirmation round is requested to produce this revised proposal.

Primary references: [RFC 9470 sections 3 and 6.1](https://www.rfc-editor.org/rfc/rfc9470.html),
[RFC 9700 section 4.14](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14), and
[OIDC Core section 2](https://openid.net/specs/openid-connect-core-1_0.html#IDToken).

Verification limits: current source and test definitions were inspected; tests and live browser
flows were not run. The conclusions concern proposal consistency and inspected implementation
boundaries, not demonstrated exploitability or runtime success. Source inspection was against HEAD
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` with existing uncommitted application changes. Only this
backlog was edited for this review.

## Owner decisions after the Codex review (2026-11-03)

Recorded by Claude Code from the owner's answers. The consolidated requirements are in
`plans/backlog/2026-11-03-op-mediated-step-up-requirements-consolidated.md`.

- Proposal A is chosen: refresh can neither create a new step-up event nor extend its deadline. This
  supersedes the "window ends earlier at a refresh" result of Decision 7b.
- Passkey deletion (E2): a step-up by any method is sufficient. The no-lockout check stays separate.
- The refresh token is rotated at step-up with the existing rotation protections (Decision 9
  stands). Claude Code's earlier recommendation not to rotate is withdrawn.
- The point of no return is the OP commit (token issuance and code consumption). OP issuance and RP
  installation are recorded separately in Chronicle.

## Owner decisions on the consolidated requirements (2026-11-03)

Recorded in `plans/backlog/2026-11-03-op-mediated-step-up-requirements-consolidated.md` as items 20
to 22: the step-up event overwrites the standard grant fields (`oidc_auth_time`, `oidc_acr`,
`oidc_amr`); the old Base-mediated step-up is replaced in one change without coexistence; Base app
is the first target and the design assumes general RPs.

## Owner decision after review-1 (2026-11-03)

Scope of the replacement (answer to SU-R1): Base org is included in this change together with Base
app; the old Base-mediated ordinary step-up is replaced in both without coexistence. Retained flows
(bootstrap, credential registration, full reauthentication, emergency and Secret refusals) keep
their own behavior and their shared classes. Consolidated items 21 and 22 were revised accordingly.

## Owner decision on the class name (2026-11-03)

The `acr` value names the fact that an active re-authentication was performed in the RP session (not
a strength tier, not "mfa"), as an all-lowercase URN. Candidate: `urn:umaxica:acr:reauthenticated`,
to be fixed in the unit 0 contract. Recorded in consolidated item 6 and in
`specs/op-mediated-step-up/spec.md`.

## Owner decisions on the class form and routing (2026-11-03)

- Class form: an HTTPS URI under an owned host instead of a URN (`urn:umaxica` is not a registered
  RFC 8141 namespace and is already used for `ProblemType` and the local JWT issuer default). No RFC
  requires HTTPS; the basis is OIDC Core section 2 (form left to the parties) and RFC 8820 / BCP 190
  (URI structure under the owner's control). Candidate `https://<owned-host>/acr/reauthentication`;
  the host is open.
- Routing: new and changed routes use Rails `namespace` with `resource`/`resources` only (class A of
  `adr/rails-routing-resourceful-policy.md`). The route table is in
  `specs/op-mediated-step-up/contracts/contract-draft.md` section 10.
- Class URI host (owner, 2026-11-03): `visa.umaxica.app`; no page is served for it. The value is
  `https://visa.umaxica.app/acr/reauthentication`, one value for both realms (an identifier only).
- Intended-grant binding (owner, 2026-11-03): option 1, the RP's signed client assertion carries the
  expected grant `sid` and `sub` at the token exchange, and the OP refuses a mismatch before commit.
  `id_token_hint` and stored ID Tokens are not used; existing sessions need no fresh sign-in (O-8
  withdrawn).

## Formal acceptance (owner, 2026-11-03)

The owner accepted unit 0 of `specs/op-mediated-step-up/` (spec, plan, contract revision 6, consumer
inventory revision 3 and the ADR amendment drafts) after Codex review-8 reported no blocking
finding. The four ADR amendments were inserted with the date 2026-11-03. Implementation is not yet
authorized; it starts only from an owner-approved instruction file.
