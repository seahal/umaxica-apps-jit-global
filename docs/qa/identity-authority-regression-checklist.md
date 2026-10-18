# Identity Authority Regression Checklist

## Purpose

Use this checklist when implementing or reviewing Identity Authority inversion work.

## Current Status

Status: `COMPLETE_WITH_BOUNDED_LEGACY` as of 2026-06-05.

The retained-authority closure removed the sign-side step-up freshness fallback. App Google/Apple
settings social link and unlink are now Sign-owned durable mutations. Link requires a Sign-started
server-side `intent: "link"` flow with OAuth state and `social_link` step-up; implicit
already-signed-in auto-link is rejected. Unlink requires Sign-side authentication, authorization,
`social_unlink` step-up, Turnstile, and the viable-login-method guard. Grantless established app
social login remains rejected on the sign callback. Refresh rotation now lives physically in
`Acme::RefreshTokenService`; `Sign::RefreshTokenService` is a behavior-free compatibility subclass.

Remaining bounded legacy:

- Unknown / incomplete social signup and account-selection remains bounded sign compatibility and
  must be moved to acme decision flow later. These paths still complete on the sign-side
  compatibility path (`SocialAuthService.handle_callback`). "Established account" is approximated by
  the birthdate-present predicate in `acme_social_login_completion_supported?` (birthdate is the
  final sign-up checkpoint); it is documented in code and guarded by tests. It does not expand link,
  unlink, token, or established-login authority.
- `Sign::RefreshTokenService` remains as a compatibility namespace only. Target paths call
  `Acme::RefreshTokenService`; the sign subclass implies no sign-side refresh issuer or authority
  and is pinned by `IdentityAuthorityInversionGuardTest`.

## Negative Checks

- `sign/id` does not issue, refresh, rotate, revoke, list, or display user sessions.
- `sign/id` does not issue access tokens, refresh tokens, downstream tokens, or step-up freshness.
- `sign/id` does not store `recent_auth`, `sudo`, `last_step_up_at`, or equivalent freshness.
- `sign/id` does not own preference writes, settings, dashboards, withdrawal, account lifecycle, or
  session-management UI.
- Auth settings does not own identity, profile, session-management, activity, or lifecycle routes
  except for the approved credential ceremony-backed settings matrix: app
  passkeys/TOTP/Google/Apple, com passkeys, and org passkeys/Entra.
- Retired Auth settings routes for emails, telephones, birthdate, secrets, secret credentials,
  sessions, revocations, activities, and withdrawal are unroutable. They must not redirect to Base,
  return compatibility `410 Gone`, or remain available through alias helpers.
- Migrated acme pages render acme templates/layouts and do not reuse `sign/...` account, preference,
  dashboard, settings, withdrawal, session-management, or sign-out templates.
- Migrated acme forms submit to acme routes; they do not generate `id.umaxica.*` or other sign-host
  form actions. Credential ceremony links to sign remain allowed only when they intentionally start
  a retained ceremony.
- `/sign/out`, if retained, redirects to acme logout and does not mutate session/token state.
- `core` and `line` reject sign-issued session/access/downstream tokens.
- Social provider callbacks on `sign/id` may durably commit app settings social link only for a
  server-side settings-link intent; acme must not final-commit app settings social link/unlink.
- WebAuthn/passkey ceremonies on `sign/id` return evidence only; acme owns session/account effects.
- Redirect targets and OAuth/OIDC `state` do not carry authentication result facts.
- Existing sign-side physical tables/models are not treated as sign-side authority.
- Sign-side OAuth/OIDC, JWKS, userinfo, revocation, logout, and edge token endpoints are
  compatibility redirects, delegates, wrappers, or blocked endpoints only.
- Established app Google/Apple social login completes through acme-owned session decision.
- Grantless established app Google/Apple social login is rejected on the sign callback; it must not
  create a sign-side session.
- App settings social link final commit occurs on the Sign callback only after Sign-side auth,
  authorization, `social_link` step-up, provider, OAuth state, session/user consistency, and replay
  checks pass.
- App settings social unlink final commit occurs on Sign only after Sign-side auth, authorization,
  `social_unlink` step-up, Turnstile, and viable-login-method checks pass.
- Unknown social signup or account-selection paths, if retained, are classified as bounded legacy
  and have tests proving they do not expand link, unlink, token, or established-login authority.

## Positive Checks

- `acme/www` commits session, account, preference, token, authorization, and freshness state.
- Delegated ceremonies use Base-issued grants and Auth-issued, short-lived opaque results.
- The current Base/Auth OIDC result is purpose-, surface-, and transaction-bound; its digest and
  generation are durable in the surface-local PostgreSQL transaction, while the raw capability is
  short-lived Valkey transport. PostgreSQL finalization and authorization-grant redemption are
  atomic within the ticket database, and retries cannot create a second Browser/RP Session.
- Downstream services trust acme-issued downstream tokens only.
- `acme/www` owns OAuth/OIDC discovery, JWKS, authorization, token, userinfo, revocation, OIDC
  logout, and edge token refresh endpoints for new flows.
- `acme/www` owns final contact, authenticator, and established social login commits. Acme
  social/settings link and unlink paths are compatibility/delegation paths only.

## OWASP Review

- Destructive or freshness/token mutation endpoints are non-GET.
- CSRF protection remains enabled for browser-authenticated mutating endpoints.
- Compatibility redirects use fixed route helpers and do not accept arbitrary external targets.
- Provider tokens, refresh tokens, session tokens, raw passwords, TOTP seeds, and ceremony secrets
  do not appear in URLs, logs, grant payloads, or browser-carried result payloads.
- OAuth/OIDC state, nonce, PKCE, issuer, audience, and redirect URI validation remain covered.
- Refresh token rotation remains one-shot and replay-safe; compromised families are revoked.
- JWKS exposes public keys only.

## NIST / Identity Review

- `acme/www` owns session, token, account, and step-up freshness decisions.
- `sign/id` remains a credential ceremony executor and provider callback surface.
- AAL, `acr`, `amr`, and `auth_time` semantics are preserved.
- Step-up freshness is recent reauthentication committed by acme-owned state.
- Social provider proof is external identity evidence, not local session authority.
- Contact OTP remains contact/verifier proof; it is not treated as phishing-resistant.
- Passkey/WebAuthn, TOTP, and secret credential enrollment distinguish ceremony from final binding.

## Compatibility Classification Checks

Classify every remaining sign-side hit as one of:

- `CEREMONY_ALLOWED`
- `PROVIDER_CALLBACK_ALLOWED`
- `COMPATIBILITY_WRAPPER_ALLOWED`
- `BOUNDED_LEGACY_UNKNOWN_SOCIAL`
- `OUT_OF_SCOPE_SIGN_IN_SIGN_UP`
- `DEAD_CODE_REMOVE`
- `AUTHORITY_VIOLATION_FIX`

Do not leave sign-side session, token, account, preference, freshness, or lifecycle mutations
unclassified.

For the Auth settings to Base identity migration, `COMPATIBILITY_WRAPPER_ALLOWED` is not an allowed
classification for retired settings routes. Non-exception Auth settings routes must be classified as
`AUTHORITY_VIOLATION_FIX` until removed, or `DEAD_CODE_REMOVE` when no callsite remains.

## Guard Commands

```bash
rg -n "logout_current_session!|logout_all_sessions_for!|RefreshTokenService|refresh_access_token|transparent_refresh|TokenExchangeService|AuthorizeService|userinfo|revocation|revoke|jwks|openid|oidc|oauth|last_step_up_at|last_step_up_scope|recent_auth|sudo|Preference::|Withdrawal::Lifecycle|SocialAuthService|create_session|dashboard|settings" app/controllers/sign app/controllers/concerns/sign app/services/sign app/views/sign app/helpers test/controllers/sign test/integration
rg -n "sign.*IdP|id.*IdP|sign.*session|sign.*token|sign.*refresh|sign.*preference|sign.*settings|sign.*dashboard|sign.*withdrawal|sign.*OAuth|sign.*OIDC|sign.*step-up|sign.*freshness|sign.*social.*link|sign.*account" docs plans adr
rg -n "surface:SIGN|SIGN_.*issuer|SIGN_.*jwks|sign.*issuer|sign.*token|Sign::RefreshTokenService" app lib test config
```

## Regression Commands

```bash
bin/rails test test/controllers/acme/oauth_oidc_authority_test.rb
bin/rails test test/controllers/acme/authenticator_lifecycle_authority_test.rb test/controllers/acme/step_up_intent_authority_test.rb
bin/rails test test/services/identity/passkey_ceremony_contract_test.rb test/services/identity/passkey_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/totp_ceremony_contract_test.rb test/services/identity/totp_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/secret_credential_ceremony_contract_test.rb test/services/identity/secret_credential_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/step_up_ceremony_contract_test.rb test/services/identity/step_up_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/telephone_ceremony_contract_test.rb test/services/identity/telephone_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/email_ceremony_contract_test.rb test/services/identity/email_ceremony_acme_transaction_test.rb
bin/rails test test/services/identity/social_ceremony_contract_test.rb test/services/identity/social_ceremony_acme_transaction_test.rb
bin/rails test test/integration/social_auth_login_test.rb test/integration/social_auth_app_flow_contract_test.rb test/integration/social_auth_unlink_test.rb test/integration/social_link_unlink_test.rb
bin/rails test test/integration/sign/app/credential_removal_constraints_test.rb test/integration/sign/com/credential_removal_constraints_test.rb test/integration/sign/org/credential_removal_constraints_test.rb
bundle exec rails test test/controllers/sign test/controllers/acme
```
