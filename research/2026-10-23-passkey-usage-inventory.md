# Passkey usage inventory

Research note, not a contract. Static reading of commit `6e4d70d0b` on 2026-10-23 (UTC 2026-10-22),
plus `bin/rails routes` filtered for `passkey|webauthn`. Nothing was executed against a browser or
an authenticator. Written as input for the `docs/security/passkeys.md` overview and for the Passkey
work unit of the 2026-10 authentication cycle; the decisions themselves live in the ADRs listed at
the end.

## Routes (65)

Host families: Auth = `auth.umaxica.{app,com,org}`, Base = `www.umaxica.{app,com,org}`.

| Use | Routes | Surfaces | Controller |
|---|---|---|---|
| Sign-in entry page | `GET /sign/in/passkey/new` | APP, COM, ORG | `Auth::<S>::Sign::In::PasskeysController` |
| Sign-in options | `POST /sign/in/passkey/options` | APP, COM, ORG | `Auth::<S>::Sign::In::Passkey::OptionsController` |
| Sign-in verification | `POST /sign/in/passkey/verification` | APP, COM, ORG | `Auth::<S>::Sign::In::Passkey::VerificationsController` |
| Sign-in second factor (challenge) | `GET /sign/in/challenge/passkey/new`, `POST /sign/in/challenge/passkey` | APP, COM | `Auth::<S>::Sign::In::Challenge::PasskeysController` |
| ORG Emergency (Standby) | `GET /sign/in/emergency/passkey/new`, `POST …/options`, `POST …/verification` | ORG | `Auth::Org::Sign::In::Emergency::{Passkeys,Passkey::Options,Passkey::Verifications}Controller` |
| Sign-up registration (telephone path) | `GET/POST/PATCH/PUT/DELETE /sign/up/check/telephone/passkey` | APP, COM | `Auth::<S>::Sign::Up::Check::Telephone::PasskeysController` |
| Step-Up verification | `GET /verification/passkey/new`, `POST /verification/passkey/options`, `POST /verification/passkey` | APP, COM, ORG | `Auth::<S>::Verification::PasskeysController` |
| Registration for a signed-in Identity | `GET /verification/registration/passkey/new`, `POST …/options`, `POST …/registration/passkey` | APP, COM, ORG | `Auth::<S>::Verification::Registration::PasskeysController` |
| Management (list, show, rename, delete, start registration) | `GET/POST /identity/passkeys`, `GET /identity/passkeys/new`, `GET/PATCH/PUT/DELETE /identity/passkeys/:id` | APP, COM, ORG (Base) | `Base::<S>::Identity::PasskeysController` |

Base Step-Up and setup pages that hand over to these ceremonies also mention Passkey:
`Base::<S>::VerificationsController`, `Base::<S>::Verification::{Setups,Completions}Controller`.

## Controllers → concerns

| Controller group | Concerns |
|---|---|
| APP/COM sign-in options and verification | `PasskeySignInFlow` (347 lines), `SignInPhaseBindingControllerSupport` |
| APP/COM sign-in challenge (second factor) | `PasskeyCeremonyContext`, `SignInPhaseBindingControllerSupport`; calls `Webauthn::AssertionVerifier` directly |
| ORG Normal sign-in (after Entra) | `SignOrgNormalPasskeyCeremony`; entry page uses `OrgNormalSignInTransaction` |
| ORG Emergency | `SignOrgStandbyPasskeyCeremony` |
| APP/COM sign-up telephone | `PasskeyRegistrationFlow`, `SignUpSequenceControllerSupport`, `SignUpExplicitStepControllerSupport`, `<S>SignUpCheckpointPage` |
| Step-Up | `AuthStepUpCeremonyContext`, `AuthStepUpPasskeyCeremony` → `IdentityStepUpPasskeyVerificationCommitter` |
| Registration for a signed-in Identity | `AuthPasskeyRegistrationCeremony` |
| Base management | `BaseIdentityPasskeyManagement` |

## Shared WebAuthn components

| Component | File | Role |
|---|---|---|
| `Webauthn::RegistrationVerifier` | `app/services/webauthn/registration_verifier.rb` | Registration options (`resident_key: "required"` on APP, COM, ORG; attestation `none`; UV from `UvPolicy`) and attestation verification |
| `Webauthn::AssertionVerifier` | `app/services/webauthn/assertion_verifier.rb` | Assertion verification |
| `Webauthn::ChallengeStore` | `app/services/webauthn/challenge_store.rb` | Challenge issue and consumption |
| `Webauthn::UvPolicy` | `app/values/webauthn/uv_policy.rb` | Per-purpose UV registry (all `required`) |
| `Webauthn::Surface` | `app/values/webauthn/surface.rb` | APP/COM/ORG surface table |
| `Webauthn::AuthenticatorMetadata` | `app/values/webauthn/authenticator_metadata.rb` | Authenticator naming and metadata |
| `Webauthn::RelyingPartyConfigResolver` | `app/resolvers/webauthn/relying_party_config_resolver.rb` | RP ID and origin per surface |
| `Webauthn::OptionsSerializer` | `app/serializers/webauthn/options_serializer.rb` | Options JSON for the browser |

Registration options are built in two places, both passing `user_name:` from
`PasskeyCeremonyContext#passkey_resource_display_name` (first Email address, else the public id):
`app/controllers/concerns/passkey_ceremony_context.rb:38` and
`app/controllers/concerns/auth_passkey_registration_ceremony.rb:31`. These are the change points for
the account-label ADR.

## Models

| Surface | Credential | Status | Ceremony | Audit outbox | Capacity |
|---|---|---|---|---|---|
| APP | `ClientPasskey` | `ClientPasskeyStatus` | `ClientPasskeyCeremonyTransaction`, `IdentityPasskeyCeremonyCandidate` | `ClientPasskeyAuditOutbox` | `MAX_PASSKEYS_PER_USER = 10` (model validation) |
| COM | `VisitorPasskey` | `VisitorPasskeyStatus` | `VisitorPasskeyCeremonyTransaction`, `VisitorPasskeyCeremonyCandidate` | `VisitorPasskeyAuditOutbox` | `MAX_PASSKEYS_PER_VISITOR = 10` |
| ORG | `OperatorPasskey` | `OperatorPasskeyStatus` | `OperatorPasskeyCeremonyTransaction`, `OperatorPasskeyCeremonyCandidate` | `OperatorPasskeyAuditOutbox` | `MAX_PASSKEYS_PER_STAFF = 10` |

The capacity of ten is a model validation; concurrent last-slot registration is the open gap in
`plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`.

## Other readers

- `AuthenticationBase#mfa_bypassed_for_auth_method?` treats `passkey` as satisfying the MFA
  requirement (`authentication_base.rb:3401`); the Security Mode migration changes this area.
- `PasskeySignInFlow#passkey_eligible_for_sign_in?` checks passkey status, discard and
  `actor.active?`, not the sign-up status (the AX26-1 question).

## Tests

442 test files mention `passkey` or `webauthn`. Largest groups: `test/integration` 58,
`test/models` 45, `test/operations` 40, `test/services` 18, `test/policies` 13,
`test/controllers/auth` 10, `test/controllers/base` 19, `test/unit/security` 7,
`test/security/invariants` 6. Static guards for WebAuthn live in
`test/unit/security/webauthn_invariants_test.rb`.

## Decisions that govern this area

| Record | Current effect |
|---|---|
| `adr/passkey-identifier-first-sign-in.md` | Identity selection before the ceremony; `allowCredentials` empty on APP/COM; amended 2026-10-23 |
| `adr/passkey-authenticator-account-label.md` | Non-identifying `user.name`; ORG discoverable; ten per Identity |
| `adr/credential-response-nondisclosure.md` | ORG discoverable + UV; Emergency options without descriptors; one refusal message |
| `adr/webauthn-discoverable-direct-sign-in.md` | Partially superseded (usernameless selection) |
| `adr/webauthn-user-handle.md` | Opaque immutable user handles |
| `adr/passkey-uv-policy.md` | UV registry |
| `adr/passkey-authenticator-metadata.md` | Authenticator metadata |
| `adr/passkey-current-state-limit-and-chronicle-outbox.md` | Lifecycle, owner serialization, Chronicle outbox; capacity ten |
| `adr/authentication-security-mode.md`, `adr/authentication-security-cycle-consolidation-2026-10-15.md` | `ADVANCED` requires a Passkey and keeps at least two |

Current-behavior pages to reconcile when the overview is written:
`docs/security/webauthn-architecture.md`, `docs/security/webauthn-security-invariants.md`,
`docs/security/org-emergency-access.md`.
