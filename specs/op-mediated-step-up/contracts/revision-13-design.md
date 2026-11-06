# Revision 13 design proposal

Status: accepted by the owner on 2026-11-04 with conditions (review 9 resolved). Conditions: the
complete inventory of paths that take OP locks before principal locks is produced in unit 6b and
every such path is fixed before unit 7; the O-9 owner endpoint and admission persistence shape are
reported in `zero.md` with the implementation. This document amends contract revision 12 as
revision 13.

## O-9: Base-to-Auth admissions

Use one short-lived, single-use admission for each of two purposes: passkey registration and
starting a social link. Base authenticates the local RP session and verifies the signed access-token
event and current authorization before requesting an admission. The admission binds realm, Base
client, actor subject, OP grant `sid`, local RP session reference, browser binding, purpose, and,
for social linking, the exact provider. The browser cannot select an actor or change the purpose or
provider. Expiry is the earlier of the proof deadline and a proposed five-minute admission deadline,
checked against the owner database clock.

The existing `ClientAuthAdmissionBinding` and `OperatorAuthAdmissionBinding` live in the OP
databases; their existing parent and `base_token_id` constraints assume an OP root token. An RP cell
cannot supply that token. Propose an authenticated Visa owner endpoint, called by the Base Self-RP
with its registered client authentication and its verified access token, to resolve the grant and
root at the OP, recheck the event and issue the admission. Reuse the existing realm-specific
admission lifecycle and opaque transport where their parent and binding constraints can be extended
safely; do not reinterpret a missing root token as authority. Define an explicit new admission
parent/purpose if the existing ceremony parent cannot represent the link operation. Auth redeems the
admission atomically once and binds the resulting Auth ceremony to its actor, session, purpose and
provider. Auth reads the admission result, not RP evidence or step-up commit facts. The provider
callback and completion must match the same bound ceremony and actor.

Base delivers the admission to Auth only in a POST body, never in a GET URL, query string or
Referer. Auth first attaches the admission to its own browser ceremony, then sends that same browser
through the existing Base ceremony-binding confirmation round trip. Base checks its authenticated RP
session, session reference and browser nonce, and confirms the locked binding with its
CSRF-protected POST. Auth verifies that confirmation belongs to its attached ceremony and atomically
redeems the admission before starting a provider redirect or passkey ceremony. The existing
confirmation code expects an OP root token; adapt its binding to the verified RP session and grant
rather than treating a missing root as valid. A bare admission or confirmation reference is not
proof of browser ownership. Base checks CSRF and its browser/session binding before issuance. No
admission, token, callback state or provider credential is logged. Reject missing, expired,
replayed, switched-session, wrong-realm, wrong-actor, wrong-purpose and wrong-provider admissions.
Test a stolen admission and confirmation reference in a second browser both before and after
attachment: neither browser may start a provider redirect or passkey ceremony without the
originating Base browser confirmation; also test CSRF, concurrent redemption and confirmation
expiry. Network or storage uncertainty fails closed; an unknown redemption outcome is not retried as
a new authorization. The endpoint, persistence shape, exact browser handoff and transaction
boundaries require review before implementation: the existing admission state machine and OP/RP
database separation do not establish these details automatically.

## O-10: authority through the principal commit

Use the established actor-first order: lock the Zenith principal, then take OP device session,
current root and affected grant locks in deterministic order, recheck the event and authorization,
commit the Zenith write while the OP locks remain held, then end the read-only OP transaction. This
preserves `adr/root-login-establishment-boundary.md` and the device → root → child order in the
applicable sign-out contract. The locks serialize revocation with the protected commit; no
cross-database atomic transaction is claimed.

The implementation must explicitly manage the two database transactions and commit order. Ordinary
nested Ruby transaction blocks that commit the inner OP transaction before the outer Zenith
transaction do **not** satisfy this design. Refuse an enclosing transaction that prevents a
confirmed Zenith commit while OP locks are held. Acquire the actor lock before any OP lock; audit
all verifier and mutation callers for OP-before-principal acquisition and change any such reverse
edge before activation. No complete reverse-edge inventory has yet been verified, so this remains an
implementation prerequisite, including multi-actor and multi-session paths. Existing actor-first
`OidcTokenExchangeCoordinator`, `BaseStepUpAdmissionIssuer`, `CredentialSecurityTransition` and
identity writers are not to be reversed merely to implement O-10. Identity stop paths that deliver
to OP after the Zenith commit retain their epoch and delivery guarantees.

The OP transaction must be read-only for this authorization boundary. If the Zenith write fails
before commit, roll it back, end the OP transaction, and report failure. A lost Zenith commit
acknowledgement is indeterminate: resolve against a durable operation-specific idempotency or audit
record and do not repeat a non-idempotent write or report success until resolved. Failure to end the
read-only OP transaction after a confirmed Zenith commit cannot undo that commit; release the
connection and report the confirmed principal outcome with a diagnostic. Do not perform network I/O
while locks are held. Deadlocks and timeouts fail closed; retry only the entire fresh transaction
when demonstrably idempotent. Test both lock winners, expiration while waiting, principal rollback,
unknown commit, and audit failure on independent connections.

## O-11: surface ownership and move inventory

Auth keeps login, signup, verification, external provider callbacks and link completion. Its APP
`settings/apple` and `settings/google` keep only POST create for link start, entered via O-9. ORG
Entra remains sign-in only with administrator-provisioned identities: the owner retained
`adr/org-entra-id-sign-in-boundary.md` and rejected self-service linking or unlinking on 2026-11-04.
Remove the Auth `/settings` index and provider show/edit/destroy routes without aliases. Move
provider display and unlink to Base, proposed as `identity/social_identities` index/show/destroy
with a strictly allowlisted provider per realm and owner-scoped authorization. The Base unlink
writer checks step-up evidence at its own commit boundary. APP TOTP enrollment and management move
to Base `identity/totps`; ORG has no TOTP. Email/telephone registration and passkey rename/removal
already belong to Base.

Move the Auth APP TOTP controller, enrollment and handoff
(`app/controllers/auth/app/settings/totps_controller.rb` and
`settings/totps/{enrollments,handoffs}_controller.rb`) and
`src/pages/auth/app/settings/totps/new.tsx` to Base ownership; integrate with the existing Base TOTP
controller and pages. Split `auth/app/settings/{apples,googles}_controller.rb`: retain only link
create on Auth and move display/unlink and the corresponding
`src/pages/auth/app/settings/{apples,googles}/{show,edit}.tsx` to Base. Move the ORG Entra status
display to Base while preserving the existing refusal of self-service unlink and the sign-in-only,
pre-provisioned identity contract; do not add an Entra link admission or provisioning path. Remove
the Auth APP/ORG settings index controllers and the currently unrouted settings removals controllers
after confirming no remaining caller. Preserve Auth social OAuth and
`auth/app/social/link_completions_controller.rb` with the admission-bound completion.

For ordinary credential registration propose Auth `settings/passkey` with resourceful registration,
options and handoff routes, and move
`auth/{app,org}/verification/registration/passkeys_controller.rb` and their pages to that path. The
existing verification registration path is also reached by first-authenticator bootstrap
(`auth/{app,org}/verification/setups_controller.rb`), while bootstrap was explicitly excluded and
cannot require an existing step-up. Keep bootstrap at its existing
`verification/registration/passkey` entry unchanged. The ordinary settings entry and bootstrap share
ceremony code but have distinct purposes; only the ordinary settings entry requires O-9.

Update inbound destinations in `base/app/identities_controller.rb`,
`base/app/application_controller.rb`, `base/app/identity/totps_controller.rb`,
`base_identity_passkey_management.rb`, `base_ceremony_binding_confirmation.rb`,
`app_social_ceremony_entry.rb`, `sign_social_authentication_endpoint.rb`, `social_auth.rb`, Auth APP
OmniAuth callbacks and link completion, and both Auth verification setup and registration
controllers. Redirect completed links to the appropriate Base identity page using an allowed target;
keep provider callback URLs on Auth. Review all route helpers and static paths in
`config/routes/auth.rb`, `config/routes/base.rb`, `src/` and Visa before removal. No dedicated
settings helper file was found under `app/helpers` in this inspection.

Move or retain explicit translations in both `config/locales/en.yml` and `ja.yml`, including
`views.sign.app.settings.{apples,googles}.show.*`, `views.sign.app.settings.totps.new.*`,
`sign.app.settings.totps.*`, and the controller's shared settings/action keys; preserve keys still
used elsewhere. Reconcile the Auth APP/ORG settings, verification passkey and setup controller
tests, `test/controllers/auth/route_naming_test.rb`,
`test/controllers/auth/settings_removal_compatibility_test.rb`,
`test/config/org_settings_routes_test.rb`,
`test/unit/security/{public_entrypoint_inventory,action_policy_usage}_test.rb`, and affected social,
passkey and TOTP integration tests. Test removed routes and all new destinations, including
bootstrap and no-lockout behavior.

## O-12: Base in shared runtime

`RpCellLocalSession#rp_cell_process?` currently tests only `RuntimeRole::RP_ROLES`;
`BrowserRpAuthentication` uses it for access resolution and refresh. Propose selecting RP-cell
behavior for Base APP and ORG RP-owned controllers under `shared`, using the trusted route owner and
runtime role at the controller boundary. Do not globally change the concern for Auth, Visa, Base
OP/domain endpoints or other surfaces. Base sign-in/callback must create the local RP session and
cookies; an old OP-chain-only Base browser session needs a new RP sign-in. Refresh uses the local
generation protocol. Base sign-out must follow the local-session-first and Visa confirmation
behavior of `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`,
including its 2026-11-01 amendment; validate callback, local revocation, refresh revocation and
back-channel logout in development.

In an RP cell `BrowserRpAuthentication` sets no OP security context, so `current_session` and
`VerificationBase#current_session_token` cannot supply the OP root. The following direct
dependencies must be addressed or explicitly reported before activation; presence in this inventory
does not claim an exercised failure for every route:

| Base feature / files                                                                                                                                                                                  | Disposition                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Provider link start, passkey registration (`base_identity_passkey_management`, binding confirmation)                                                                                                  | O-9 admission; O-11 routes.                                                                                                                                                                                                                                                                                                                                                 |
| APP TOTP; APP/ORG passkey management; APP/ORG email and telephone registration and APP contact mutation (`identity/totps`, `identity/passkeys`, `identity/emails`, `identity/telephones` controllers) | O-11 Base-owned flows need RP-session/evidence-aware write boundaries; do not pass an absent root token.                                                                                                                                                                                                                                                                    |
| APP `secrets`, `secret_issuances`, `secret_presentations`, and Secret-specific verification                                                                                                           | Out of scope: under the RP path refuse explicitly with a localized message and logged reason code; tracked in `plans/backlog/2026-11-04-base-rp-cell-root-token-features.md`.                                                                                                                                                                                               |
| APP/ORG `verification/{setups,completions,cancellations}` retained bootstrap and full-reauthentication branches                                                                                       | Bootstrap is explicitly out of scope. Inventory the retained branches and keep them fail closed; do not claim bootstrap works in the RP cell.                                                                                                                                                                                                                               |
| APP `identity/mfa/challenges`                                                                                                                                                                         | Q-1 is in scope; implement the Security Mode change with RP evidence and the O-10 commit boundary.                                                                                                                                                                                                                                                                          |
| ORG `identity/secret_credentials`, `identity/removals`                                                                                                                                                | Out of scope: under the RP path refuse explicitly with a localized message and logged reason code.                                                                                                                                                                                                                                                                          |
| APP/ORG `identity/sessions` and `identity/revocations/others`                                                                                                                                         | Out of scope: session listing and revocation refuse explicitly under the RP path with a localized message and logged reason code. Do not treat an RP session ID as an OP root ID; tracked in the root-token features backlog.                                                                                                                                               |
| APP `selector`                                                                                                                                                                                        | In scope: resolve the actor from the verified Access Token and store persona selection against the local RP session. Do not read or write OP root-token selection for an RP request. Validate every selected persona against candidates owned by that actor. A missing local selection is established only by an explicit selector write; a GET does not auto-select.       |
| ORG `selector`                                                                                                                                                                                        | In scope: resolve the actor from the verified Access Token and store persona selection against the local RP session. Do not read or write OP root-token selection for an RP request. Validate every selected persona against candidates owned by that actor. A selected session's later selector update is refused without mutation and directs the browser to `/switcher`. |
| APP/ORG `identity/sessions` and `identity/revocations/others`                                                                                                                                         | Out of scope: refuse explicitly under the RP path with a localized message and logged reason code. Do not treat an RP session ID as an OP root ID; session listing and revocation remain tracked in the root-token features backlog.                                                                                                                                        |
| `VerificationBase`, `ActorSupport`, `BaseAdmissionBrowserBinding`, `BaseStepUpCompletion`                                                                                                             | Shared concern callers include retained root-bound flows. Classify each reachable Base use and preserve Auth/Visa behavior.                                                                                                                                                                                                                                                 |

Before the switch, complete the root-token caller inventory against both direct calls and included
concerns; the list above identifies the current lexical matches and does not assert transitive
completeness. Prove APP and ORG route isolation, sign-in, refresh, sign-out and session behavior.
Unit 7 also requires the owner's manual `shared` development run: Base verification → Visa → Auth
method choice → Visa → Base target. No second OP-chain step-up path is introduced.

## Security review and acceptance gate

Review cross-realm and cross-provider substitution, replay and expiry at each boundary, concurrent
session revocation versus the principal commit, partial commit and audit outcomes, secret-free
diagnostics, and the bootstrap exception. O-9's endpoint and replay storage, O-10's complete lock
graph and ADR amendment, the accepted O-11 bootstrap distinction, and O-12 refusal behavior require
Claude Code review and owner acceptance. Revision 13 was accepted with conditions on 2026-11-04;
unit 7 remains gated on their implementation and verification.
