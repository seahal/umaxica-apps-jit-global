# OP-Mediated Step-Up: Consolidated Requirements (Revision 2)

Date: 2026-11-03

Status: Backlog. Requirements only. No ADR is amended and no implementation is authorized. This file
separates what is effective from what is open or superseded, so that implementers do not have to
infer precedence from `plans/backlog/2026-11-03-op-mediated-step-up-standards-alignment.md`, which
remains the append-only history and rationale.

Sources: owner decisions and answers (2026-11-03), the Codex critical reviews recorded in the
history file, and Claude Code's verification in the same session. "Unverified" marks claims not
checked against the current tree.

## 1. Purpose and shape

Reauthenticate the currently signed-in Identity before a sensitive operation, similar to sudo, for
any RP and not only Base. The path is RP → OP (Visa) → Auth → OP → RP. Auth is a ceremony service
that is neither OP nor RP. Step-up is not sign-in and is separate from foolproofing (confirmation
words and screens belong to the operation owner and are not a step-up condition).

## 2. Effective decisions

1. Reuse. A step-up result is reusable for every sensitive operation until its deadline. No
   operation is exempt into authentication on every execution. (Reverses
   `adr/authentication-security-mode.md` D3.)
2. Sign-in is not step-up. When an operation needs step-up and the RP holds no reusable step-up
   result, a separate ceremony runs, requested with `prompt=login` (a fresh sign-in does not satisfy
   it; OIDC Core 3.1.2.3; verified in `authorization_session_sufficient?`). The RP checks locally
   first and requests reauthentication only when needed. Reuse applies to step-up results only.
3. Scope. A result is reusable only inside the RP session where it was performed; not across RPs,
   surfaces or sessions. Design lead, unverified: record the event on the per-client grant row, not
   the OP session.
4. Declaration. The controller owning the operation declares that it needs step-up (a
   `before_action` hook, as today). Verification of the evidence is shared and not copied into
   controllers or RPs. Operation authorization and final-writer checks stay with the owner.
5. Outside this mechanism. First-authenticator bootstrap, credential registration, and the refusal
   for emergency and Secret sessions keep their own rules, including the primary-authentication
   freshness rule.
6. Class. The class is a single agreed value: step-up performed or not. No strength tiers, no
   per-method classes. `acr` is a case-sensitive string on the wire: preserve the exact value, and
   refuse missing or unsupported evidence instead of defaulting or normalizing (the current
   `normalize_acr` returns `aal1` for blank and downcases; verified at
   `authorization_token_claims.rb:58-61`). Naming (owner, 2026-11-03): the value states the fact
   that an active re-authentication was performed in this RP session, not a strength tier and not
   the word "mfa" (a passkey sign-in is already multi-factor). It is an HTTPS URI (owner,
   2026-11-03; earlier URN choice superseded), all lowercase, so it survives any lowercasing;
   candidate `https://visa.umaxica.app/acr/reauthentication` (owner, 2026-11-03: HTTPS form instead
   of URN, host `visa.umaxica.app`, no page served). Custom `acr` values are allowed by OIDC Core
   section 2 ("parties ... agree upon the meanings"); OP advertises it in `acr_values_supported`.
7. Methods. Permitted methods and authentication conditions for the owner's Security Mode are
   enforced server-side at Auth and at OP evidence acceptance before the class is issued; offering
   them only in Auth's UI is insufficient.
8. Window. The deadline is fixed and exclusive, anchored to the step-up `auth_time`: valid while
   `auth_time <= now < auth_time + 5 minutes`. The RP compares this itself; token `exp` is not the
   window. The clock-skew allowance for this comparison is stated explicitly (the access-token
   leeway is 30 seconds today). The 15 and 5 minute maxima of ADR D2 remain upper bounds. Missing,
   malformed, non-finite, future or expired event time is refused.
9. Refresh. Refresh can neither create a new step-up event nor extend the deadline. Refresh may
   issue another token describing the same already verified event (RFC 9470 6.1: `acr` and
   `auth_time` do not change on renewal). A retained historical class must not authorize an
   operation after the deadline. This supersedes the "window ends at a refresh" result of the
   earlier Decision 7b.
10. Rotation. The step-up exchange rotates the refresh token under the existing rotation
    protections, so refresh tokens issued before the step-up stop working at that moment.
11. Challenge. An unmet requirement is answered with HTTP 401 and a `WWW-Authenticate` challenge
    (`insufficient_user_authentication`, RFC 9470). It is distinct from missing-login recovery and
    from an ordinary 403 authorization denial. A shared challenge handler serves scripted clients; a
    top-level HTML response carries an explicit step-up entry. Starting step-up is a CSRF-protected
    action, never repeats the protected mutation automatically, and neither receiving the challenge
    nor showing the entry creates proof.
12. RP verification. The RP verifies the class, event time, session and Identity binding on every
    protected request through one shared verifier. Having requested step-up is never evidence of it.
13. Essential request. The RP requests the class with an essential `acr` through the `claims`
    parameter. An OP that cannot satisfy it fails the request with
    `unmet_authentication_requirements` (defined in the OpenID document referenced by RFC 9470
    section 5). Verified absent today: Visa `authorize_params` reads neither `claims` nor
    `acr_values`. Access-token issuance and verification must be consistent with the ID Token.
14. Same session. Step-up keeps the OP session, device session, per-client grant, RP session and
    `sid`; it updates the authentication event only. These identifiers are distinct and must be
    named precisely. A purpose-bound completion branch resolves and updates the exact initiating
    grant and RP session; the existing guards that reject an already-enrolled grant or a live local
    session for sign-in stay intact.
15. Failure. Authentication failure, cancellation, expiry, dependency failure, invalid evidence or
    an indeterminate outcome supplies no new authority and the operation does not proceed. A
    communication failure never bypasses step-up. Dependency failures stay distinguishable from
    challenges.
16. Point of no return. The OP commit (authorization code consumed, grant event recorded, tokens
    issued). A response lost after it is recovered under the existing credential-recovery/sign-in
    contract, not by rollback, replay of the consumed code, or retry of a possibly consumed
    credential. A new attempt creates a new bound transaction. "Indeterminate grants no authority"
    is softened to: authority is limited to the event the user actually earned, bounded by the fixed
    deadline and the RP-session scope.
17. Accounting. OP issuance and RP installation are recorded separately in Chronicle. Ceremony
    success is never recorded as operation success or installation success. Accounting correctness
    is not deferred.
18. Passkey deletion (E2). A step-up by any method suffices. The active-count (no-lockout) check
    stays a separate rule. ADR text must state this, because E2's wording is an ADVANCED example.
19. Revocation. Forced sign-out, Security Mode change, recovery and withdrawal keep their existing
    owners and effects. Deferring a step-up-specific window-closing mechanism does not defer or
    weaken them; an invalid session makes the proof unusable because the proof is scoped to the RP
    session.
20. Record location (owner). A successful step-up overwrites the standard fields `oidc_auth_time`,
    `oidc_acr` and `oidc_amr` of the per-client grant usage for the initiating RP session. Refresh
    needs no change to carry the event. The sign-in `acr` and `auth_time` are not kept in that grant
    afterwards (they remain on the OP session side). After the deadline the grant still shows the
    step-up class, so every consumer must go through the shared verifier of item 12, which checks
    the class and `auth_time` together. The unused `step_up_until` claim is not adopted.
21. Old path (owner). The existing Base-mediated ordinary step-up is replaced in one change for Base
    app and Base org, without coexistence (`generic/no-compatibility-layer.mdc`). Shared classes
    (`BaseStepUpAdmissionIssuer`, `BaseStepUpCompletion`, `BaseSelfRpCredentialIssuer`,
    `BaseAuthAdmissionCoordinator`) are removed only where no retained consumer depends on them:
    bootstrap, credential registration, full reauthentication and the emergency and Secret refusals
    (item 5) keep their own behavior. The consumer inventory decides what is deleted. (Revised
    2026-11-03 after review SU-R1.)
22. Scope (owner). Base app and Base org in this change; the design assumes general RPs (a shared
    verifier and per-RP registration), and other RPs follow later. (Revised 2026-11-03: Base org
    added, replacing "Base app first".)
23. Security Mode downgrade (owner, 2026-11-03, "for now"). The owner-initiated `ADVANCED` to
    `NORMAL` change is satisfied by the ordinary reusable step-up (obtained with a passkey while
    still `ADVANCED`); the "purpose-limited, one-time" wording of
    `adr/authentication-security-cycle-consolidation-2026-10-15.md` section 2.5 no longer applies.
    The revocation of every session and refresh token after the change stays.
24. Intended-grant binding (owner, 2026-11-03, option 1). The OP binds the requesting client's grant
    under the active OP session before the ceremony; at the token exchange the RP's signed client
    assertion carries its stored `sid` (the grant public id) and `sub`, and the OP refuses any
    mismatch before commit with no event and no rotation. No ID Token is stored and no fresh sign-in
    is required for existing sessions.

## 3. Threat note: refresh credentials

A refresh token is a longer-lived, separate asset (RFC 9700 4.14, cited by the review, not checked
by me). Possession of the raw token alone is not the capability: use also needs the applicable
client authentication, sender binding and browser/session binding. Rotation at step-up invalidates
refresh tokens issued before the step-up. The residual exposure after rotation is the legitimate new
refresh credential obtaining tokens that describe the same event until the deadline, which is not a
new or extended event. It is not equivalent to theft of one short-lived access token and is not
claimed to be.

## 4. Superseded or withdrawn entries

- Decision 10 (403 with an RFC 9470 header and the plain-text variants): replaced by item 11.
- Decision 2's implementation note about `prompt=login`: withdrawn (wrong).
- Decision 7a's consequence that Auth's UI enforces ADVANCED methods: replaced by item 7.
- Decision 7b "the window ends earlier at a refresh": replaced by item 9. Decision 8's "credentials
  stay unchanged": replaced by item 16.
- Claude Code's recommendation not to rotate the refresh token: withdrawn; item 10.
- "The RP→OP leg already exists": true only for the request side; the completion side is item 14.

## 5. Open items

1. The RP-session-scoped event writer: locking and integration with the refresh snapshot and
   late-response installation, now that item 20 fixes the location. Updating an OP-global event,
   keeping the wrong grant or restoring an old authentication snapshot would break scope or the
   deadline.
2. Representation of a result that the OP committed and the RP never installed. With item 16 a later
   refresh exposes the committed event inside the deadline; state that explicitly and test it.
3. (Resolved by item 21: replace in one change.)
4. The step-up exchange's token response and the existing callback installer (the ordinary callback
   requires both access and refresh credentials, `oidc_callback.rb:171-182`); define a
   purpose-specific installer and its concurrent-update contract.
5. The skew value for item 8; the exact `WWW-Authenticate` parameters; the challenge handler's
   contract.
6. A Security Mode change inside the window; the deferred window-closing events and mechanism.
7. The controller inventory (implementation time) and the audit event names (spec time).
8. Whether the OP can satisfy item 13 end to end (not today); DBSC continuity for item 14
   (unverified).

## 6. Prerequisites and required amendments

- Prerequisite: the missing Chronicle retention policy rows
  (`plans/backlog/2026-11-03-chronicle-retention-policy-reference-rows.md`).
- Amend before implementation: `adr/op-auth-rp-authentication-responsibility-separation.md` (path
  C), `adr/authentication-security-mode.md` (D2, D3, E2, E4),
  `adr/step-up-authentication-redesign.md`, `docs/security/step-up-operation-inventory.md`, and the
  state-machine diagrams and inventory in `docs/mermaid/` for any new flow or status axis
  (`docs/mermaid/README.md`).

## 7. Acceptance tests to add (extend, do not duplicate)

Existing coverage to extend: `test/services/oidc/token_exchange_service_test.rb:329` (rotation and
event time), `test/controllers/base/oauth_freshness_e3_test.rb:23` (`prompt=login`),
`test/operations/rp_refresh_committer_test.rb:54,65,183`,
`test/operations/rp_refresh_logout_concurrency_test.rb:209`. New cases: the exact deadline instant
and adjacent values; delayed issuance and installation; malformed, future and non-finite event
times; a refreshed token after the deadline does not authorize; sign-in alone does not satisfy;
another session of the same client and another RP do not satisfy; a lost response after OP commit;
step-up completion racing refresh, cancellation and logout; duplicate, stale and conflicting
completions; the 401 challenge for a scripted client and a full-page navigation without automatic
replay; `acr` exact-case preservation and refusal of a defaulted class.
