# Authentication

Applies to browser authentication on each supported surface; method availability remains
surface-specific. These are durable requirements, not current verification results.

- AUTH-1: State-changing browser requests retain Rails CSRF, Origin and Fetch Metadata protection;
  ceremony binding adds protection rather than replacing it. Scoped exceptions: the Sign-in path
  continuation GETs of `adr/sign-in-path-continuation-protocol.md` (the six D-100/D-101 conditions)
  and the Back-Channel Logout receiver (`ActionController::API`, Logout Token signature only).
- AUTH-2: A browser-bound ceremony refuses stale, mismatched, cross-browser and replayed admission.
  A Design D continuation GET requires Fetch Metadata navigation/document, verifies the host-only
  browser binding before touching the one-time record, consumes atomically, returns the same next
  redirect for a same-browser repeat within issuance + 10 s, sends `no-store` and `no-referrer`, and
  leaves a clean final URL. HEAD and all other non-navigation requests are refused.
- AUTH-3: Missing or contradictory authentication evidence produces an explicit refusal, without
  inferring another actor, credential, browser or assurance level.
- AUTH-4: Auth supplies ceremony continuity, not an independent general login session or authority
  token issuer; preserve the explicitly accepted admission-binding exception.
- AUTH-5: App Apple/Google link completion requires a live Ticket grant. A callback or grant begun
  before Source unlink or account termination cannot authenticate a later owner, reattach or sign up
  the released subject; the release proof survives removal of the app identity row. Org Microsoft
  Entra ID is company-owned and is not automatically unlinked by app account withdrawal.
- AUTH-6: The Device sign-in mock is retired: `/sign/in/device` reaches no controller and sign-in
  selection offers no device option, while the remaining sign-in methods keep working.
- AUTH-7: Base and Auth require a valid CSRF token on state-changing requests, including JSON and
  same-origin requests with Fetch Metadata. A missing or invalid token or an origin mismatch is
  refused before any update or flow issuance. Protocol callbacks keep their own state, nonce, PKCE
  and signature checks, and passing through Jump exempts nothing.
- AUTH-8: Initial issue, OIDC Code exchange, Refresh and credential reissue preserve the bound
  root's authentication context. Org Emergency Access follows ordinary policy rules and never gains
  Step-Up through a continuation. OIDC Access authentication requires an explicit known string
  `authn_ctx` matching the current bound root; absent, malformed and mismatched claims refuse.
  Canonical SQL NULL on an org root means Normal; it is not an absent Access claim. App/com remain
  Normal-only. Preserve the independent Refresh authority, replay protection, root lifetime and
  root-login cooldown when correcting rejected credentials. See
  [Org authentication context](../security/org-emergency-access.md#authentication-context-and-token-claims).
- AUTH-9: Only an ACTIVE, unexpired, unrotated root token with a usable device session can
  authenticate Browser RP requests, issue or refresh OIDC credentials, establish Step-Up, or
  continue credential ceremonies. Historical `RESTRICTED` (103), expired, revoked and unknown
  statuses fail before principal creation. Waiting and non-Full Access sessions cannot reach MFA
  reset; the retired RestrictedSessionGuard is not an alternate authentication boundary.

- AUTH-10: In separated RP cell processes, Refresh resolves only the opaque local session public ID.
  An ended session, revoked OP binding or disabled local principal prevents dispatch. Before
  installing a response, recheck its exact issuer/client/realm/subject/sid/contract epoch and local
  generation under the binding-before-session lock order shared with callback and logout. A
  mismatched response never advances the installed generation or changes credential metadata.
- AUTH-11: An unresolved RP Refresh attempt retains its original input binding, generation and
  deadline. Another tab cannot dispatch a second rotation for that pending input. After uncertain
  delivery or a dependency/invalid-protocol outcome, a subsequent request may only recover the same
  receipt; it cannot resend the predecessor to rotate or extend the five-second window.
- AUTH-12: RP token exchanges have a two-second total HTTP budget; receipt queries have one second
  and inherit the remaining four-second dispatch budget and original receipt expiry. Expired
  deadlines prevent dispatch, and late results cannot install credentials. Network deadlines never
  interrupt a database transaction. These controls do not prove receiving capacity.
- AUTH-13: Callback and back-channel logout select the fixed cell writer and serialize on the same
  sid anchor. Callback checks fresh writer time after acquiring it, refuses expired authority and
  disabled principals, and cannot reopen a logout tombstone. Concurrent duplicate logout deliveries
  return the committed result with one receipt, rather than failing its unique index.
- AUTH-14: Base self-RP reissue locks and reloads its canonical actor before OP device/root/grant
  claim updates, refuses stopped or superseded-epoch authority, and leaves claims unchanged on
  refusal. Token rotation separately rechecks current actor authority through its OP commit.
- AUTH-15: Separated RP request authentication reads local session, binding and principal without
  query-cache reuse from the fixed cell writer, and compares local expiry with its fresh database
  clock. Application clock lag and a caller's reading role cannot extend that local authority.
- AUTH-16: OP Refresh refuses a Grant whose contract epoch is missing or differs from the realm's
  current epoch with `invalid_grant`, without rotating or rewriting it; a pre-cutover family is
  never restamped into the current profile.
- AUTH-17: An RP verifying OP-issued JWTs uses only the fixed public JWKS. An unknown key ID gets at
  most one refetch; while that fetch fails, the unknown key stays untrusted and an already cached
  key remains usable only within its fresh and bounded stale windows.

- AUTH-18: APP/COM/ORG Passkey lifecycle mutations and their audit outbox facts share the owning
  principal transaction. Additional metadata cannot replace the authoritative surface, target UUID
  or actor reference. Delivery preserves nil system actors and business occurrence time after
  credential deletion; retry after Chronicle commit before acknowledgement creates no second event.
  See [Passkey lifecycle and audit](../security/passkey-lifecycle-and-audit.md).
- AUTH-19: APP/COM/ORG sign-in and sign-up: a Base → Auth admission reference (`entry_ref`) or an
  Auth → Base result reference presented from any browser other than the one that started the flow
  never attaches a ceremony that Base confirms, never redeems the admission, never yields an
  authentication result Base accepts and never establishes a Root Session. Its worst effect is
  denying the legitimate attempt while the reference lives (an accepted residual risk; the user
  restarts). Re-verify with foreign-browser refusal tests at attach, confirmation, redemption and
  result receipt whenever the sign-in or sign-up relay components change. See
  [Base/Auth authority](../../adr/base-auth-ceremony-and-seven-rp-boundary.md).

- AUTH-20: APP/COM email and telephone sign-up entry requires explicit policy consent (`"1"` or JSON
  `true`); telephone entry also requires explicit MFA-use consent. Missing, null, empty, unchecked
  and unsupported consent values refuse before creating registration or OTP artifacts.
- AUTH-21: APP/COM contact-entry replacement validates Turnstile and submitted inputs before
  superseding the browser's active sign-up. A rejected replacement preserves the flow, locator,
  pending contact and principal and queues no OTP. An accepted replacement retains the existing
  HALTED and cleanup semantics. See
  [contact entry](../security/sign-up-sequence.md#contact-entry-validation-and-replacement).

- AUTH-22: Protected CAPTCHA entry points reject missing and failed tokens server-side. Enabling
  outage degradation still refuses missing/empty tokens, failed challenges and missing secrets; only
  explicitly upstream-unavailable results may pass under the incident flag. See
  [Turnstile](../security/turnstile.md).
- AUTH-23: APP/COM email sign-in resend requires confirmed admission, original browser/surface
  binding and an unexpired authenticated state. Cross-browser, expired and retargeted states cannot
  dispatch; destination cooldown and verification budgets remain effective. This bound continuation
  needs no fresh CAPTCHA. See
  [resend exception](../security/turnstile.md#email-sign-in-resend-exception).
- AUTH-24: APP/COM unbound email candidates cannot select an actor or receive login/recovery OTP,
  even if their email status says VERIFIED. Rejected attempts preserve the candidate and issue no
  login credentials. See
  [binding contract](../security/identity-resolution-and-credential-binding.md).
- AUTH-25: APP/COM security-lock recovery requires the existing verified effective email OTP proof
  and an eligible account lock. Recovery authority is scoped to lock recovery and does not itself
  issue a login session or reset a password. See
  [recovery scope](../security/credential-gateway.md#current-security-lock-recovery-scope).

- AUTH-26: First-party Auth/Preference access and OIDC token verification applies the fixed
  30-second clock-skew allowance to `iat` as well as applicable `nbf`/`exp` checks. Expired-access
  decoding for logout/revocation relaxes only expiration and never authorizes a request. Apple
  RS256/RS512 verification behavior remains covered by the accepted upstream drift contracts. See
  [JWT validation decisions](../../adr/jwt-validation-and-key-risk-decisions.md).

- AUTH-27: Known and unknown Secret identifiers use the same normalized identifier attempt
  partition. Distributing requests across IPs never reveals lookup success through the account
  attempt limit. Independent IP limits remain enforced.
- AUTH-28: Org Emergency options disclose no real credential descriptors, including across repeated
  requests. Challenge cookies use fixed-length selected-Operator binding or a non-authenticating
  sentinel. Missing, disabled, wrong-owner and invalid-signature Passkey assertions share the
  generic credential refusal and verification response floor.
- AUTH-29: APP/COM withdrawal and security-lock recovery keep real/dummy session payload lengths
  equal, cover complete OTP issuance with the response floor, and never authenticate dummy state.
- AUTH-30: Closed Org invitation provisioning refuses every invitation state before code lookup,
  preserves existing records and retains the common surface rate limit. See
  [nondisclosure decisions](../../adr/credential-response-nondisclosure.md).

- AUTH-31: APP/COM/ORG authorization-code coordination preserves the request validator's protocol
  error classification: an unsupported response type is `unsupported_response_type`, an inactive
  resource is `access_denied`, and a disallowed scope is `invalid_scope`. Refused requests return no
  success redirect; missing required parameters remain `invalid_request`. See
  [authorization request profile](../../adr/oidc-authorization-request-profile.md).

Sources:
[authentication contract](../../.agents/harnesses/rules/generic/authentication-boundaries.mdc),
[Base/Auth authority](../../adr/base-auth-ceremony-and-seven-rp-boundary.md). Broader scenarios:
[identity authority regression checklist](../qa/identity-authority-regression-checklist.md).
