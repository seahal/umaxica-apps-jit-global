# OP-mediated step-up (two-step) authentication

Status: accepted (owner, 2026-11-03). Unit 0 accepted together with `contracts/contract-draft.md`
(revision 6), `contracts/consumer-inventory.md` (revision 3) and
`contracts/adr-amendment-drafts.md`, which are applied to the ADRs. The owner accepted explicitly:
the scope (Base app and Base org ordinary step-up in one cutover, retained flows unchanged); the
reusable 300 second RP-session evidence, sign-in not counting; refresh rotation at step-up and the
sign-in recovery after a response lost past the OP commit; the removal of the check that the
credential used for the step-up is still active; the 15 minute RP pending lifetime and the 60 second
dispatch deadline; the class value, the signed client-assertion expectation as a local extension,
Q-1 (for now) and the refusal of DPoP-bound grants. Implementation authorized on 2026-11-03 through
the owner-approved `implementation-instruction.md` (Codex implements).

## Authority and scope

Source: the owner's decisions of 2026-11-03, items 1 to 22 of
`plans/backlog/2026-11-03-op-mediated-step-up-requirements-consolidated.md` (history and rationale
in `plans/backlog/2026-11-03-op-mediated-step-up-standards-alignment.md`), and the Codex review in
`review-1.md`. Revision 2 includes Base org, as the owner decided after SU-R1.

Purpose: reauthenticate the currently signed-in Identity before a sensitive operation, for any RP,
along RP → OP (Visa) → Auth → OP → RP, with standard OIDC authentication context and an RFC 9470 401
challenge. Auth stays a ceremony service that is neither OP nor RP.

In scope: Base app and Base org ordinary step-up; the OP request and issuance support; Auth method
enforcement; the RP shared verifier, start action and installer; the 401 challenge and its front-end
handler; the controller declarations of both surfaces; replacement of their Base-mediated ordinary
step-up in one change; durable audit; DBSC continuity of the completion.

Retained with their own behavior (not replaced): first-authenticator bootstrap, credential
registration, full reauthentication, and the refusals for emergency and Secret sessions. They keep
the shared classes they depend on. The consumer inventory (plan unit 0) fixes exactly what is
deleted.

Excluded: other RPs (follow-up); the mechanism that closes a window after dangerous events
(deferred; existing logout, Security Mode, recovery and withdrawal revocation stay as they are);
foolproofing and confirmation screens; identity proofing; new providers; production or external
operations.

## Definitions fixed by this spec

- Class: one string, compared byte for byte. It states that an active re-authentication was
  performed in this RP session (not a strength tier), as an all-lowercase HTTPS URI under an owned
  host (`https://visa.umaxica.app/acr/reauthentication`; owner decision, no page served).
- Event: the tuple of `oidc_auth_time`, `oidc_acr` and `oidc_amr` of one grant, read as one
  snapshot.
- Deadline: the event `auth_time` plus five minutes, exclusive at the end, no extra skew allowance.
- Outcomes of a ceremony: refused before commit; committed with unknown delivery; delivered but not
  installed; installed. The protected operation executes only from a new, explicit request after
  install.
- Allowed method: a method the server permits for the owner's current Security Mode.

## Acceptance

Outcome categories (RV-71). Each boundary has its own response contract, fixed in the plan unit 0
outcome table: resource challenge (AC-9), missing login, authorization denial, invalid provenance or
CSRF, invalid callback, code or binding, terminal ceremony conflict, and dependency failure. In
every case the operation does not run. A "refusal" below names the category it belongs to; the
challenge of AC-9 is only the outcome of a protected-resource request whose session, authentication
and authorization prerequisites are valid but whose step-up proof is absent or insufficient. Invalid
callbacks, CSRF, issuer, PKCE, proof-binding errors, logout and stale completion never become an
instruction to resume that transaction.

- AC-1: After a successful step-up the owner can perform at least two different sensitive operations
  in the same RP session without another ceremony until the deadline. Satisfying step-up removes
  only that prerequisite; independent authorization, the current session, CSRF and the no-lockout
  rule still apply.
- AC-2: A sign-in, however recent, does not satisfy step-up. With no valid result the RP starts a
  ceremony that the OP performs although a session exists (`prompt=login`). Registration evidence
  never gives ordinary step-up freshness. Bootstrap is outside this change; unit 6 verifies only
  that this change does not alter its behavior. Its pre-existing Base RP-cell ownership issue
  remains tracked separately.
- AC-3: A result is usable only in the RP session where it was performed; another session of the
  same client, another RP and another surface are refused. A valid event does not authorize another
  target or tenant.
- AC-4: The class is preserved exactly, case included, from request to the RP check. A missing,
  blank or unsupported class is refused; nothing defaults or normalizes it.
- AC-5: The check is `auth_time <= now < auth_time + 5 minutes`. The anchor, the instant just
  before, the exact end and just after are tested. Missing, malformed, non-finite and future event
  times are refused as an unmet requirement. JWT expiry is validated independently. A missing or
  unreadable clock source is an explicit failure, not a guessed default.
- AC-6: Refresh can neither create an event nor extend the deadline; a refreshed token describes the
  same event, and a retained class after the deadline authorizes nothing. Event fields are read as
  one snapshot under the same current-grant check as issuance. Responses are ordered by causality,
  not by operation type: a response whose initiating installation generation or transaction has been
  superseded cannot replace the current credentials, while a refresh started after a completed
  step-up, or a step-up started after a completed refresh, installs and keeps the event. Both
  arrival orders of overlapping work and both sequential orders are tested; the rotated refresh
  credential is accounted for before a late response is installed.
- AC-7: A step-up rotates the refresh token under the existing rotation protections. A refresh token
  issued before it is refused afterwards, with the existing reuse consequences. An access token
  issued earlier stays acceptable until its own expiry and cannot extend freshness.
- AC-8: The OP accepts one canonical essential request: a `claims` request with an essential `acr`
  of the class and an essential `auth_time`. It defines the behavior of combined `claims` and
  `acr_values`, of unsupported values and of malformed input (invalid request) versus an unmet
  requirement (`unmet_authentication_requirements`). A voluntary downgrade is refused. Access token
  and ID Token carry consistent claims. Discovery advertises support only in the release that
  completes the chain, and only for the enabled realms; the other realms are unchanged.
- AC-9: For a protected-resource request with valid prerequisites, an unmet requirement is answered
  with HTTP 401 and a `WWW-Authenticate` challenge (`insufficient_user_authentication`), distinct
  from missing-login recovery, an authorization 403 and a dependency failure.
- AC-10: A scripted client recognizes the challenge instead of treating it as sign-out; a full-page
  navigation gets a usable HTML response with an explicit entry; Inertia, fetch and full-document
  handling are each defined. The start action is CSRF-protected with Origin and Fetch Metadata
  checks, performs no write on GET or HEAD, validates the return target as a same-RP target, never
  replays the protected mutation, and neither the challenge nor the entry creates proof.
- AC-11: Every protected request goes through one shared verifier (class, event time, session and
  Identity binding, audience). Having requested step-up is never evidence of it.
- AC-12: Cancellation, expiry, authentication failure, dependency failure, invalid evidence and a
  refusal before commit leave the session unchanged and give no new authority; a failure never
  creates or extends an event and never removes an earlier valid one. For a committed event with
  unknown delivery or a refused installation, the failed request never executes by itself, and the
  committed event is governed by AC-14. A communication failure never bypasses step-up.
- AC-13: The completion is bound to a server-selected initiating context: the exact current RP
  session, Identity and the intended existing grant, carried by the authorization transaction and
  code and verified on both completion boundaries. Wrong same-client session, wrong subject or
  issuer, foreign browser, code or PKCE mismatch, expired pending flow, logout and stale completion
  are refused in their own categories (invalid callback or binding, terminal conflict, missing
  login), not as a step-up challenge. It creates no principal, no account switch, no root login, no
  session-limit or cooldown change and never revives a logged-out session. The sign-in guards for an
  existing grant and a live local session stay intact and are tested.
- AC-14: The OP commit is the point of no return, and no rollback, grace window or replay of the
  consumed code is promised. After it, a lost response leaves the owner unable to use the old
  refresh token (AC-7); recovery follows the existing credential-recovery and sign-in contract. The
  owner accepted this consequence of rotating at step-up. A refresh with a valid current credential
  inside the deadline exposes the committed event. The three situations (response lost before
  delivery; received but installation refused; later valid refresh) are tested separately.
- AC-15: Durable Chronicle facts exist for OP issuance, RP installation, cancellation, expiry,
  refusal and indeterminate delivery, with safe correlation (no raw credentials or full request
  data), duplicate handling and a defined behavior when the audit write fails. One authoritative
  issuance, installation or terminal fact exists per outcome; a replay never creates another success
  or terminal transition, and a rejected attempt is a separate observation whose recording or
  deduplication, correlation and persistence-failure policy the unit 0 contract fixes. For unknown
  delivery the component records its observed uncertainty, not an invented delivery or installation
  fact. They are integrated before the new writers are activated. Ceremony success is never recorded
  as operation or installation success.
- AC-16: Allowed methods are enforced server-side at Auth and at OP evidence acceptance before the
  class is issued, including after a policy change between start and completion.
- AC-17: For Base app and Base org no ordinary step-up path other than the new one can set the
  step-up event. The retained flows still work, and a regression test covers each.
- AC-18: Passkey deletion, and the owner-initiated `ADVANCED` to `NORMAL` change (owner decision,
  for now), accept the ordinary step-up obtained with any allowed method (a passkey while
  `ADVANCED`); the no-lockout rule is a separate check and stays. E2 is amended explicitly, not
  described as a clarification.
- AC-19: Logout, Security Mode change, recovery and withdrawal revoke as before, including races
  before, during and after a ceremony; an invalid session makes the proof unusable.
- AC-20: Current documents match the delivered behavior: amended ADRs state the reversals of D3 and
  path C and the amendment of E2; state-machine diagrams, the transition inventory and the step-up
  operation inventory change together with the code, not before it.
- AC-21: Stale, duplicate and conflicting requests are rejected by the ceremony state machine
  through one named writer with a database-clock recheck and absorbing terminal states, without an
  extra token, event, rotation, success or terminal transition (a rejected attempt may be observed
  under AC-15). The winner of a cancel versus complete race is specified, a missing allowed method
  is refused, and attempt limits persist across restarts.
- AC-22: The completion keeps the DBSC binding of the device session: proof requirements for a bound
  session still apply, the installer neither clears nor rebinds it, DPoP checks are not weakened,
  and missing, mismatched, revoked or invalid proof is refused.

## Material risks and unresolved decisions

Decided in `contracts/contract-draft.md` (revision 6) and not repeated here: the class value, the
request and challenge shapes, the outcome table, the data shapes and state machines, the
intended-grant binding by signed client assertion, the one-dispatch lifecycle, the audit outbox with
its result, retention and payload mapping, the DPoP and DBSC preservation rules, and the lifetimes.
Remaining risks:

- Scale (`contracts/consumer-inventory.md`): 48 footprint files and 22 consumption sites move to the
  verified evidence in one cutover; the old root-token evidence must not stay live beside it.
- Overwriting the grant leaves the class visible after the deadline; only the shared verifier makes
  that safe.
- Rotation at step-up means a lost response forces a new sign-in (AC-14); the owner accepted this
  tradeoff.
- Intentional policy change for acceptance: the check that the credential used for the step-up is
  still active is removed for ordinary step-up (contract section 9).
- The OP reads neither `claims` nor `acr_values` today, and the client assertion carries no
  expectation; both are new work in Visa app and Visa org.
- The test baseline is unreliable (committed residue in single-process runs leaks into parallel
  workers); a narrow baseline is recorded in unit 0, which is not an acceptance gate.
- Runtime DBSC, DPoP, delivery and race behavior are unverified until implementation.
- Deferred: the routine-credential-change window closing (O-7); existing enforcement revocation is
  not deferred.

## Verification approach

Test at public boundaries: OP authorization and token endpoints, the RP protected request, the start
action, the 401 response and the front-end handler. Extend existing coverage
(`token_exchange_service_test`, `oauth_freshness_e3_test`, `rp_refresh_committer_test`,
`rp_refresh_logout_concurrency_test`) instead of duplicating it. Boundary tests cover the deadline
instants and missing, empty, zero and malformed inputs. Run the narrowest files first and a full run
before closure. Run the front-end build and the i18n checks. Build and migration construction is
verified by running it and recording evidence, not by setup tests.
