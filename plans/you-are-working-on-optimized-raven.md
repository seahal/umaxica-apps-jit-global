# Umaxica Auth Security Audit — Read-only Pass

**Date:** 2026-06-18 **Mode:** Read-only evidence-gathering. No code edited. No tests added. No
fixes implemented. **Scope:** OAuth 2.0 / OIDC, redirect URI, PKCE, code lifecycle, token endpoint,
refresh tokens, JWKS, OIDC metadata/issuer, logout (front+back-channel), session binding/step-up,
OTP/TOTP/passkey, password reset, rate limiting, audit/chronicle, host/issuer integrity, CORS,
Rails.cache for security state, admin/operator gate, encryption.

All findings cite `path:line` from the working tree at audit time. Previous findings were not
trusted — every claim was re-derived from current code.

---

## 1. Audit reliability

- **Git status:** Working tree is **NOT clean.** Many `M`/`A` files staged (controllers, services,
  lib/, db/_.sql structure dumps, plans/, notes/, views). New files include
  `app/services/oidc_client_secret_resolver.rb`,
  `app/services/oidc_client_stores_static_client_store.rb`,
  `app/services/oidc_redirect_uri_validator.rb`, and several `lib/config*values*_` files. Audit
  reflects working-tree state, not last commit.
- **Rails boot:** PASS. `bin/rails runner 'puts Rails.env'` returned `development`.
  OpenTelemetry/instrumentation loaded cleanly.
- **Migration status (development):** All listed migrations `up` across the multi-DB layout
  (`*_app_setting_db`, `*_org_setting_db`, `*_com_setting_db`, avatar dbs, etc.). No pending
  migrations.
- **Migration status (test):** Mostly `up`; observed `Schema migrations table does not exist yet`
  for at least one DB in the test multi-DB family (truncated output). This may require
  `bin/rails db:test:prepare` before targeted tests can run reliably. Not a code-correctness blocker
  for this audit (audit is static).
- **Routes availability:** PASS. Routes list expanded;
  OAuth/OIDC/sign/logout/jwks/userinfo/passkey/totp endpoints all enumerated across the three
  surfaces.
- **Blockers:** Only the test-DB partial-bootstrap above. Does not affect static evidence; flagged
  because previous attempts mixed it in.

---

## 2. Auth architecture evidence map

### Controllers (auth-relevant)

| Surface | Endpoint | Controller | | ------------------ |
------------------------------------------ |
------------------------------------------------------------------------------ |
-------------------------- | | acme/{app,org,com} | `/oauth/authorize` |
`Acme::{App,Org,Com}::Oauth::AuthorizationsController` | | acme/{app,org,com} | `/oauth/token` |
`Acme::{...}::Oauth::TokensController` | | acme/{app,org,com} | `/oauth/jwks` |
`Acme::{...}::Oauth::JwksController` | | acme/{app,org,com} | `/oauth/userinfo` |
`Acme::{...}::Oauth::UserinfosController` | | acme/{app,org,com} | `/oauth/revoke` |
`Acme::{...}::Oauth::RevocationsController` | | acme/{app,org,com} | `/.well-known/jwks.json` |
`Acme::{...}::WellKnown::JwksController` | | acme/{app,org,com} | `/oidc/logout`, `/auth/logout` |
`Acme::{...}::Oidc::LogoutsController`, `Acme::{...}::Auth::LogoutsController` | |
acme/{app,org,com} | `/edge/v0/token/{check,dbsc,refresh}` | edge token controllers | |
sign/{app,org,com} | `/sign/up/email                            | telephone/_`,
`/sign/up/check/{apple,google}/_` | `Sign::{...}::Sign::Up::*` | | sign/{app,org,com} |
`/sign/in/passkey/{options,verifications}` | `Sign::{...}::Sign::In::Passkey::*` | |
sign/{app,org,com} | `/web/v0/in/{email,telephone}/otp` |
`Sign::{...}::Web::V0::In::*::OtpsController` | | sign/{app,org,com} | `/oidc/backchannel/logout` |
`Sign::{...}::Oidc::Backchannel::LogoutsController` | | sign/{app,org,com} | `/sign/out` |
`Sign::{...}::Sign::OutsController` |

### Models (auth/credential)

`app/models/`: `client_authorization_code.rb`, `operator_authorization_code.rb`,
`visitor_authorization_code.rb`, `client_token.rb`, `client_totp_credential.rb`,
`client_mfa_level.rb`, `visitor_mfa_level.rb`, `client_email.rb`, `client_telephone.rb`,
`client_apple_identity.rb`, `operator_chronicle.rb`, `client_chronicle.rb`, plus
`concerns/refresh_token_shared.rb`, `concerns/refresh_tokenable.rb`,
`concerns/oauth_callback_stateable.rb`, `concerns/sign_flow.rb`, `concerns/otp_lockable.rb`,
`concerns/totp_ceremony_transactionable.rb`, `concerns/email.rb`, `concerns/telephone.rb`,
`concerns/has_birthdate.rb`.

### Services

OAuth/OIDC core: `oidc_authorize_service.rb`, `oidc_authorize_request_validator.rb`,
`oidc_authorization_code_issuer.rb`, `oidc_authorization_transaction_service.rb`,
`oidc_token_exchange_service.rb`, `oidc_token_revocation_service.rb`, `oidc_client_registry.rb`,
`oidc_client_secret_resolver.rb`, `oidc_client_stores_static_client_store.rb`,
`oidc_redirect_uri_validator.rb`, `oidc_client_assertion_jwt.rb`,
`oidc_access_token_authenticator.rb`, `oidc_issuer.rb`, `oidc_end_session_request.rb`,
`oidc_logout_request.rb`, `oidc_logout_token_codec.rb`, `oidc_backchannel_logout_notifier.rb`,
`acme_refresh_token_service.rb`, `jump_rt_issuer.rb`, `jump_rt_keyring.rb`,
`jump_rt_return_verifier.rb`, `jump_rt_return_policy.rb`, `jump_rt_surface.rb`,
`jit_security_jwt_anomaly_reporter.rb`.

Ceremonies: `identity_passkey_ceremony_*`, `identity_step_up_ceremony_*`,
`identity_totp_ceremony_*`, `identity_social_ceremony_contract.rb`, `identity_audit.rb`,
`common_otp_policy.rb`, `social_auth_signup_finalizer.rb`, `sign_up_step_gate.rb`,
`sign_in_otp_resend_service.rb`, `sign_in_otp_resend_policy.rb`, `client_secret_credentials_*`.

Chronicle: `chronicle_application_service.rb`, `chronicle_fallback_recorder.rb`,
`chronicle_intent_writer.rb`, `chronicle_invalidator.rb`, `chronicle_recorder.rb`,
`chronicle_result_writer.rb`.

### Jobs

`app/jobs/oidc_backchannel_logout_delivery_job.rb`, `passkey_ceremony_transaction_purge_job`,
`step_up_ceremony_transaction_purge_job`, `totp_ceremony_transaction_purge_job`.

### Concerns

`app/controllers/concerns/`: `acme_oauth_endpoint.rb`, `acme_oauth_token_endpoint.rb`,
`acme_step_up_completion.rb`, `acme_step_up_intent.rb`,
`acme_settings_oidc_connections_management.rb`, `authentication_*` (base, audit*writer,
bulletin_gate, client, cookie*_, credential*inventory_reader, current_resource_resolver,
device_binding, jwks_rendering, jwt_configuration, jwt_tokens, logout_all_sessions,
logout_current_session, logoutable, operator, redirects, sequence_gate, session_revoker, token,
token_service, visitor, withdrawal_gate), `authorization*_`(base, audit, client, operator,
token_claims, visitor),`oidc_callback.rb`, `oidc_rp_identity_provisioning.rb`, `oidc_rp_logout.rb`,
`oidc_rp_logout_receiver.rb`, `sign_passkey_sign_in_endpoint.rb`,
`sign_social_authentication_endpoint.rb`, `sign_webauthn.rb`, `sign_oidc_logout.rb`.

### Initializers / config

`config/initializers/content_security_policy.rb`, `config/initializers/omniauth.rb`,
`config/initializers/cors.rb` (entire Rack::Cors block commented — CORS disabled),
`config/environments/production.rb` (host whitelist, host_authorization).

### Routes

`config/routes/{acme,sign,core,docs,help,news,palm,base}.rb`.

### Tests (auth-relevant, observed)

OAuth/OIDC services: `test/services/oidc/token_exchange_service_test.rb`,
`oidc/authorize_service_test.rb`, `oidc/client_registry_test.rb`,
`oidc/backchannel_logout_notifier_test.rb`, `oidc_issuer_test.rb`. Controllers:
`test/controllers/acme/oauth_oidc_authority_test.rb`, `acme/app/jwks_controller_test.rb`,
`acme/com/oidc/logouts_controller_test.rb`, `acme/edge_v0_token_checks_test.rb`,
`acme/edge_v0_token_refreshes_test.rb`. Integration:
`test/integration/oidc_rp_browser_flow_test.rb`, `core_rp_browser_flow_test.rb`,
`step_up_authentication_test.rb`, `social_auth_step_up_test.rb`. Models:
`test/models/client_authorization_code_test.rb`, `concerns/refresh_token_shared_test.rb`,
`concerns/refresh_tokenable_test.rb`, `refresh_token_concurrency_test.rb`. Security invariants:
`test/security/invariants/refresh_token_reuse_invariant_test.rb`. Concerns:
`test/controllers/concerns/auth/{redirect_bulletin,operator}_test.rb`,
`authentication/{audit_writer,logout_current_session,logout_all_sessions,logoutable}_test.rb`,
`authorization_audit_test.rb`. MFA/OTP/passkey: `test/concerns/common_otp_test.rb`,
`test/jobs/{passkey,step_up,totp}_ceremony_transaction_purge_job_test.rb`,
`test/services/identity_passkey_ceremony_transaction_purger_test.rb`,
`test/services/sign/telephone_otp_delivery_test.rb`, `test/models/client_totp_credential_test.rb`.

---

## 3. Findings summary table

Severity legend: **P0** = confirmed exploitable break; **P1** = confirmed high-risk weakness or
important missing defense; **P2** = hardening / observability / future-compliance gap; **—** = none
(PASS/FALSE POSITIVE/OUT OF SCOPE).

| ID   | Control                                                  | Status                          | Severity | Evidence                                                                                                                                                                                                                                                                                                                                                                                                           | Test coverage                                                                                                                                                 | Recommendation summary                                                                                                                                                                              |
| ---- | -------------------------------------------------------- | ------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-01 | Authorization endpoint rate limit                        | PARTIAL                         | P1       | `acme/app/oauth/authorizations_controller.rb:12-21` declares `rate_limit`; com & org sibling controllers do **not**                                                                                                                                                                                                                                                                                                | App: `oauth_oidc_authority_test.rb`. Com/org: no rate-limit test observed                                                                                     | Mirror app's `rate_limit(by: [ip, client_id])` to com & org controllers                                                                                                                             |
| F-02 | private_key_jwt jti replay cache                         | NEEDS VERIFICATION              | P1       | `oidc_client_assertion_jwt.rb:31-61` validates iss/sub/aud/exp/iat/jti/typ but no jti-consume call observed; logout-token codec has a jti cache (`oidc_logout_token_codec.rb:105-114`), so the pattern exists but is not applied to client assertions                                                                                                                                                              | None observed for client-assertion replay                                                                                                                     | Reuse the Rails.cache JTI replay pattern from `oidc_logout_token_codec.rb` for the client-assertion JWT path                                                                                        |
| F-03 | Redirect URI validation — IP/userinfo/fragment           | PARTIAL                         | P2       | `oidc_redirect_uri_validator.rb:7-13` is exact-string match (good); `oidc_client_stores_static_client_store.rb:150-175` rejects http on public hosts but does **not** explicitly reject private IPs, fragments, or `userinfo@` on the stored canonical URI. `jump_rt_issuer.rb:79` does reject `uri.userinfo.present?` (different code path)                                                                       | `oidc/client_registry_test.rb:39-67` covers exact, case-sensitive, no-prefix                                                                                  | Add explicit rejection of fragments / userinfo / private IPs at the registration validator (canonical-URI ingest)                                                                                   |
| F-04 | Refresh-token revocation on logout                       | PASS                            | —        | `authentication_logout_all_sessions.rb:33-79` iterates `ClientToken / VisitorToken / OperatorToken` for the resource and calls `.revoke!` per token; also bumps `session_version` (line 46). `authentication_logout_current_session.rb:20-37` revokes device session and cascades to its tokens                                                                                                                    | `authentication/logout_all_sessions_test.rb`, `logout_current_session_test.rb`, `logoutable_test.rb`                                                          | —                                                                                                                                                                                                   |
| F-05 | Refresh token rotation + reuse detection + family revoke | PASS                            | —        | `acme_refresh_token_service.rb:36-71,99-129` + `concerns/refresh_tokenable.rb:23-66`: rotate under row-lock, detect via `rotated_at.present?`, revoke whole `refresh_token_family_id` on reuse                                                                                                                                                                                                                     | `refresh_token_shared_test.rb`, `refresh_tokenable_test.rb`, `refresh_token_concurrency_test.rb`, `security/invariants/refresh_token_reuse_invariant_test.rb` | —                                                                                                                                                                                                   |
| F-06 | Refresh token storage at rest                            | PASS                            | —        | `concerns/refresh_token_shared.rb:40-42` uses `SHA3::Digest::SHA3_384` digest; `client_token.rb` has `refresh_token_digest` binary + unique index                                                                                                                                                                                                                                                                  | covered by digest tests                                                                                                                                       | —                                                                                                                                                                                                   |
| F-07 | PKCE mandatory + S256-only + constant-time verify        | PASS                            | —        | `oidc_authorize_request_validator.rb:33-34` requires `code_challenge` and method `S256`; `client_authorization_code.rb:44` DB-constrains method to `%w(S256)`; `client_authorization_code.rb:108-116` uses `ActiveSupport::SecurityUtils.secure_compare`; token endpoint enforces verifier presence (`oidc_token_exchange_service.rb:115-120`)                                                                     | `oidc/token_exchange_service_test.rb` covers PKCE failure path; `authorize_service_test.rb` covers missing/non-S256 challenge                                 | —                                                                                                                                                                                                   |
| F-08 | Authorization code lifecycle                             | PASS                            | —        | `client_authorization_code.rb:35` TTL=10s; `:97-102` single-use via `consume!` raising on already-consumed/expired; binds user/client/redirect_uri/scope/nonce/code_challenge; token endpoint validates redirect_uri and client_id match (`oidc_token_exchange_service.rb:99-100`)                                                                                                                                 | `oidc/token_exchange_service_test.rb` invalid_grant for expired & consumed                                                                                    | —                                                                                                                                                                                                   |
| F-09 | Grant-type allowlist                                     | PASS                            | —        | `oidc_token_exchange_service.rb:55-57` allows only `authorization_code`; no implicit, ROPC, client_credentials, device_code paths                                                                                                                                                                                                                                                                                  | covered indirectly by token-exchange tests                                                                                                                    | Consider adding per-client `allowed_grant_types` if M2M support is planned later                                                                                                                    |
| F-10 | alg/kid pinning                                          | PASS                            | —        | `oidc_client_assertion_jwt.rb:33` enforces `header["alg"] == JitSecurityJwtRegistry::ALGORITHM` (ES384); `:39` resolves public key via `JitSecurityJwtRegistry.public_key_for("oidc_client:#{namespace}", header["kid"])` with namespaced kid lookup                                                                                                                                                               | `oauth_oidc_authority_test.rb` exercises ES384                                                                                                                | —                                                                                                                                                                                                   |
| F-11 | OIDC issuer integrity (host header poisoning)            | PASS                            | —        | `oidc_issuer.rb:13-15,46-54` derives issuer from `Rails.configuration.x.boot_config.fetch(:hosts)` (immutable); `production.rb:117-128` whitelists 12 canonical hosts via `config.hosts`. Request.host used **only** to choose resource-type slot (`oidc_end_session_request.rb:151-165`), then verified against canonical hosts                                                                                   | `oidc_issuer_test.rb`                                                                                                                                         | —                                                                                                                                                                                                   |
| F-12 | Backchannel logout token integrity + replay              | PASS                            | —        | `oidc_logout_token_codec.rb:78-103` validates alg=ES384, typ="logout+jwt", required claims (iss/aud/iat/exp/jti/typ/events), forbids `nonce`, requires sid UUID, exact events shape; `:105-114` atomic jti consume in Rails.cache (TTL=10m) with **fail-closed** (`raise JWT::DecodeError` if store unavailable)                                                                                                   | `oidc/backchannel_logout_notifier_test.rb`, `rp_logout_receivers_test.rb`                                                                                     | —                                                                                                                                                                                                   |
| F-13 | Backchannel logout delivery durability                   | PARTIAL                         | P2       | `oidc_backchannel_logout_delivery_job.rb:10-35` posts via `Net::HTTP` with `open_timeout: 2 / read_timeout: 3`; on exception, logs only — **no retry, no DLQ**                                                                                                                                                                                                                                                     | `oidc_backchannel_logout_delivery_job_test.rb`                                                                                                                | Add bounded ActiveJob retry (`retry_on` with backoff) and route persistent failures to a DLQ table                                                                                                  |
| F-14 | id_token_hint + post_logout_redirect_uri validation      | PASS                            | —        | `oidc_end_session_request.rb:29-69` verifies id_token_hint signature; `:47-52` validates `post_logout_redirect_uri` via `OidcClientRegistry.valid_post_logout_redirect_uri?`; `:111-123` enforces subject + sid match between hint and current session                                                                                                                                                             | `acme/{app,com,org}/oidc/logouts_controller_test.rb`                                                                                                          | —                                                                                                                                                                                                   |
| F-15 | Logout-request JTI replay                                | PASS                            | —        | `oidc_logout_request.rb:20-24,85-103` uses Rails.cache with `oidc:logout_request:consumed:` prefix, TTL 2m30s, fail-closed                                                                                                                                                                                                                                                                                         | covered by oidc logout controller tests                                                                                                                       | —                                                                                                                                                                                                   |
| F-16 | TOTP secret encryption at rest                           | PASS                            | —        | `client_totp_credential.rb:37` `encrypts :private_key`; secret column is `string(1024)`; no `deterministic: true` declared on this attribute (lookup not needed by secret)                                                                                                                                                                                                                                         | `client_totp_credential_test.rb`                                                                                                                              | —                                                                                                                                                                                                   |
| F-17 | TOTP / passkey / step-up replay stores                   | PASS                            | —        | `identity_passkey_ceremony_replay_store.rb`, `identity_step_up_ceremony_replay_store.rb`, `identity_totp_ceremony_replay_store.rb` all use DB tables (`ClientPasskeyCeremonyTransaction`, etc.) — authoritative, not cache                                                                                                                                                                                         | `identity_passkey_ceremony_transaction_purger_test.rb`, `step_up_ceremony_transaction_purge_job_test.rb`, `totp_ceremony_transaction_purge_job_test.rb`       | —                                                                                                                                                                                                   |
| F-18 | WebAuthn origin / rp_id pinning                          | PASS                            | —        | `concerns/sign_webauthn.rb:26-44` reads `WEBAUTHN_*_RP_ID` / `WEBAUTHN_*_ORIGIN` (env, not request); `:46-70` `validate_webauthn_origin!` checks against `TRUSTED_ORIGINS`; per-request `WebAuthn::RelyingParty` with `allowed_origins`+`id`                                                                                                                                                                       | passkey-related controller tests; specific origin-mismatch test not separately observed                                                                       | Add explicit origin/rp-id mismatch negative test if not already present                                                                                                                             |
| F-19 | Passkey challenge replay protection                      | PASS                            | —        | `sign_webauthn.rb:208-253` stores challenge in `session[:passkey_challenges]` with TTL=10m, max 5 per session, deleted on fetch; DB-backed transaction replay via `ClientPasskeyCeremonyTransaction`                                                                                                                                                                                                               | `identity_passkey_ceremony_transaction_purger_test.rb` and ceremony tests                                                                                     | —                                                                                                                                                                                                   |
| F-20 | OTP purpose scoping (cross-flow replay)                  | NEEDS VERIFICATION              | P1       | `concerns/otp_lockable.rb:51-91` stores/consumes OTP via shared columns (`otp_private_key`, `otp_counter`, `otp_expires_at`, `otp_attempts_count`, `locked_at`) on `client_email` / `client_telephone`. No `purpose`/`intent` column observed on the credential. `sign_in_otp_resend_service.rb:171` records purpose in the occurrence/audit record but the credential itself does not gate consumption by purpose | `common_otp_test.rb`, `telephone_otp_delivery_test.rb`; no purpose-replay negative test observed                                                              | Audit each OTP issuance/verify path to confirm caller binds purpose (sign_up vs sign_in vs step_up); if any path consumes without purpose check, add a purpose column or per-purpose credential row |
| F-21 | OTP attempt lockout                                      | PASS                            | —        | `concerns/otp_lockable.rb:34-36,128-147` MAX_OTP_ATTEMPTS=5, 15-min window, 15-min lockout, row-locked increment                                                                                                                                                                                                                                                                                                   | `common_otp_test.rb`                                                                                                                                          | —                                                                                                                                                                                                   |
| F-22 | OTP resend rate limit                                    | PASS                            | —        | `sign_in_otp_resend_policy.rb:12-34` exponential backoff (cap 15m email / 60m phone) keyed off normalized target (HMAC), counted over 5-minute window                                                                                                                                                                                                                                                              | covered by resend service tests                                                                                                                               | —                                                                                                                                                                                                   |
| F-23 | Passkey endpoint rate limit (sign in)                    | PARTIAL                         | P2       | `sign/app/sign/in/passkey/options_controller.rb:19-38` and sibling `verifications_controller.rb:19-39` declare burst (5/1m) + sustained (20/15m) rate limits keyed on `request.remote_ip` only — no account/email identifier component                                                                                                                                                                             | covered by controller tests at a basic level                                                                                                                  | Consider compositing key with the normalized identifier param (where present) to slow credential stuffing across IPs                                                                                |
| F-24 | OTP endpoint rate limit at controller layer              | PARTIAL                         | P2       | `sign/app/web/v0/in/email/otps_controller.rb:13-16` (and telephone sibling) have no `rate_limit` declaration; rely entirely on the resend-policy-service backoff                                                                                                                                                                                                                                                   | resend-policy tests                                                                                                                                           | Add a defense-in-depth IP `rate_limit` on the controllers themselves; service-layer policy is per-target, controller layer should also clip per-IP/global abuse                                     |
| F-25 | Password reset flow                                      | OUT OF SCOPE                    | —        | No `password_reset` model/controller/service grep hits. Architecture is passwordless (passkey + OTP + social). Verify with team that this is intentional (memory says architecture relies on `mfa_level` and passkey + OTP factors)                                                                                                                                                                                | —                                                                                                                                                             | Confirm passwordless intent in ADR; if intentional, add an architecture note to `docs/`                                                                                                             |
| F-26 | MFA reset / recovery codes                               | NEEDS VERIFICATION              | P2       | `client_secret_credentials_issue_recovery.rb` exists; recovery-code hash-storage/single-use semantics not traced in this pass                                                                                                                                                                                                                                                                                      | not separately enumerated                                                                                                                                     | Verify recovery codes are hashed (SHA-256+) and single-use; if not, fix and add tests                                                                                                               |
| F-27 | Step-up freshness binding                                | PASS                            | —        | `identity_step_up_ceremony_freshness_committer.rb:43-72` enforces actor + session + scope + method + AAL match before committing freshness; surface-specific (app/com/org); purpose check at `:47-48`                                                                                                                                                                                                              | `step_up_authentication_test.rb`, `social_auth_step_up_test.rb`                                                                                               | —                                                                                                                                                                                                   |
| F-28 | Sign-up step gate ordering                               | PASS                            | —        | `sign_up_step_gate.rb:26-111` enforces step prerequisites via `prior_requirements_cleared?` and returns redirect context on out-of-order access; `CREATE_STEPS = %i(otp passkey)`                                                                                                                                                                                                                                  | sign-up tests under `test/integration/`                                                                                                                       | —                                                                                                                                                                                                   |
| F-29 | Social auth signup birthdate gating                      | NEEDS VERIFICATION              | P2       | `social_auth_signup_finalizer.rb:9-10,68-74` accepts birthdate as constructor parameter and defaults `mfa_level_id: NOTHING`; the controller path that supplies the birthdate (`sign/app/sign/up/check/{apple,google}/birthdates_controller.rb`) needs confirmation it cannot be skipped via direct POST to confirmations                                                                                          | `social_auth_step_up_test.rb`; explicit "skip birthdate" negative test not separately observed                                                                | Trace controller chain end-to-end and add a skip-birthdate negative integration test                                                                                                                |
| F-30 | Chronicle audit hygiene                                  | PASS                            | —        | `chronicle_recorder.rb:5-19` redacts password/secret/token/cookie/otp/etc. by key, and Bearer/JWT/long-string/6-8-digit OTP by pattern; `identity_audit.rb:5-43` writes via append-only `*Chronicle` tables; `lib/observability_redactor.rb` scrubs sensitive keys/headers and strips URL queries/fragments                                                                                                        | `authentication/audit_writer_test.rb`, `authorization_audit_test.rb`                                                                                          | —                                                                                                                                                                                                   |
| F-31 | CORS posture                                             | PASS (intentional)              | —        | `config/initializers/cors.rb:11-19` — Rack::Cors block commented; CORS disabled. Cross-origin browser usage must rely on first-party host model                                                                                                                                                                                                                                                                    | —                                                                                                                                                             | —                                                                                                                                                                                                   |
| F-32 | OmniAuth callback origin                                 | PASS                            | —        | `config/initializers/omniauth.rb:47-103` derives callback origin from request.host but **only** for whitelisted `PUBLIC_SIGN_HOSTS`; other hosts blocked; Apple uses `provider_ignores_state: true` with app-side state validation via `CallbackStateStore`                                                                                                                                                        | —                                                                                                                                                             | —                                                                                                                                                                                                   |
| F-33 | CSRF on backchannel logout                               | PASS                            | —        | `sign/org/oidc/backchannel/logouts_controller.rb:13`, `core/{app,com}/oidc/backchannel/logouts_controller.rb:13` use `protect_from_forgery with: :null_session` (correct for spec-compliant token POST). No `skip_forgery_protection` found elsewhere in OAuth/sign                                                                                                                                                | —                                                                                                                                                             | —                                                                                                                                                                                                   |
| F-34 | Email/birthdate/telephone at-rest encryption             | PASS (note deterministic email) | —        | `concerns/email.rb:39-40` `encrypts :address, downcase: true` (deterministic for lookup); `concerns/telephone.rb` `encrypts :number`; `concerns/has_birthdate.rb` `encrypts :birthdate`; chronicle previous_value encrypted                                                                                                                                                                                        | —                                                                                                                                                             | Aware of deterministic email tradeoff; if not already documented, add to threat model                                                                                                               |
| F-35 | Admin/operator network gate                              | NEEDS VERIFICATION              | P2       | `authentication_operator.rb:19-40` provides operator accessors but no IP allowlist / mTLS / posture check observed in this path. `authentication_bulletin_gate.rb` is a step-up-via-checkpoint mechanism, not a network gate                                                                                                                                                                                       | `auth/operator_test.rb`, `redirect_bulletin_test.rb`                                                                                                          | Confirm whether operator surface (`sign/org/*`) sits behind an external network gate (load balancer ACL, VPN, mTLS) — if not, design and add one                                                    |

---

## 4. Detailed findings

### F-01 — Authorization rate limit not on com / org

- **Severity:** P1
- **Status:** PARTIAL
- **Control:** A. Authorization endpoint hardening
- **Evidence:**
  - `app/controllers/acme/app/oauth/authorizations_controller.rb:12-21` declares
    `rate_limit(to: 10, within: 1.minute, by: -> { [request.remote_ip, params[:client_id].presence || "unknown"].join(":") }, scope: "acme_app_oauth_authorize")`
    on `:show`.
  - `app/controllers/acme/com/oauth/authorizations_controller.rb` and
    `app/controllers/acme/org/oauth/authorizations_controller.rb` have **no `rate_limit`
    declaration**.
- **Missing evidence:** None — divergence is plain.
- **Exploit path:** Unbounded enumeration / abuse of `com` and `org` `/oauth/authorize` (state/nonce
  probing, client_id fuzzing, code-grant phishing prep).
- **Recommended fix:** Mirror the app declaration on the com and org controllers (same
  `(by: [ip, client_id])` composite key).
- **Required negative tests:** Burst attempt to com & org authorize returns 429 after threshold; key
  composition isolates by client.
- **Files likely involved:** the two named controllers.

### F-02 — private_key_jwt jti replay cache

- **Severity:** P1
- **Status:** NEEDS VERIFICATION
- **Control:** F. Token endpoint / client authentication
- **Evidence:**
  - `app/services/oidc_client_assertion_jwt.rb:31-61` validates iss, sub, aud, exp, iat, nbf (leeway
    via `AuthenticationJwtConfiguration.leeway_seconds`), jti, typ; signature checked via
    `JitSecurityJwtRegistry.public_key_for("oidc_client:#{namespace}", header["kid"])` at `:39`.
  - No `consume_jti!` / `Rails.cache.exist?` call observed on this path. The codebase has the
    **exact replay-cache pattern** already in `app/services/oidc_logout_token_codec.rb:105-114` (key
    `oidc:logout_token:jti:#{jti}`, TTL 10m, fail-closed) and in
    `app/services/oidc_logout_request.rb:85-103` (key `oidc:logout_request:consumed:#{jti}`, TTL
    2.5m, fail-closed).
- **Missing evidence:** Whether replay protection exists upstream/downstream of the assertion decode
  (e.g., short-window cache wrapping `OidcClientRegistry.authenticate_assertion`).
- **Exploit path:** A captured client assertion JWT can be replayed within its lifetime (the JWT's
  own `exp` window) to repeatedly authenticate the client to `/oauth/token`. With short exp this is
  bounded, but spec compliance and defense-in-depth want a jti replay cache.
- **Recommended fix:** Apply the same Rails.cache jti pattern (fail-closed) to
  `OidcClientAssertionJwt.decode!` / its caller, with TTL ≥ assertion `exp` skew window.
- **Required negative tests:** Same JWT presented twice returns `invalid_client` on the second call;
  replay-store unavailable returns `invalid_client`.
- **Files likely involved:** `oidc_client_assertion_jwt.rb`, `oidc_client_registry.rb`
  (`authenticate_assertion`), `oidc_token_exchange_service.rb` (caller).

### F-03 — Redirect URI: explicit private-IP / fragment / userinfo rejection at registration

- **Severity:** P2
- **Status:** PARTIAL
- **Control:** B. Redirect URI validation
- **Evidence:**
  - `app/services/oidc_redirect_uri_validator.rb:7-13` does exact-string match against
    `client&.redirect_uris` for both `redirect_uri` and `post_logout_redirect_uri` — the design
    preference (canonical-URI exact-match) is respected.
  - `app/services/oidc_client_stores_static_client_store.rb:150-175` only rejects `http://` on
    public hosts (loopback in non-prod is allowed). No grep hit for fragment (`#`), userinfo (`@`),
    or private-IP-range rejection at the canonical-URI ingest step.
  - `app/services/jump_rt_issuer.rb:79` rejects `uri.userinfo.present?` but that is a different code
    path (jump RT URL), not the OAuth redirect_uri registration.
- **Missing evidence:** Whether canonical URIs in the static store are reviewed at code-review/PR
  time for shape; whether an automated check exists.
- **Exploit path:** Low — exact match means a malicious form would have to be registered first.
  Still, defense-in-depth (and OIDC compliance) wants the **registration validator** to reject
  obvious foot-guns regardless of whether the registrar is a privileged operator.
- **Recommended fix:** In `OidcClientStoresStaticClientStore` (or a dedicated registration
  validator), reject URIs with fragments, with `userinfo`, with private/loopback IPs in production,
  and with non-https schemes for public clients.
- **Required negative tests:** Each rejected shape raises at boot/registration.
- **Files likely involved:** `oidc_client_stores_static_client_store.rb`,
  `oidc_redirect_uri_validator.rb`.

### F-13 — Backchannel logout delivery: no retry / DLQ

- **Severity:** P2
- **Status:** PARTIAL
- **Control:** J. Logout
- **Evidence:** `app/jobs/oidc_backchannel_logout_delivery_job.rb:10-35` posts via `Net::HTTP.start`
  (open_timeout 2 / read_timeout 3), rescues exceptions and logs but does not call `retry_on` or
  persist failures.
- **Missing evidence:** Whether downstream observability counts failures (anomaly reporter only
  fires on JWT-decode anomalies, not on delivery failures).
- **Exploit path:** RP that is briefly unreachable misses logout notification → stale session at RP.
  With single-shot delivery, a downstream restart during IdP logout dropping a single notification
  leaves a logged-out IdP session paired with an active RP session.
- **Recommended fix:** Add `retry_on Net::OpenTimeout, Net::ReadTimeout, ...` with bounded
  exponential backoff; persist exhausted attempts to a small failure table (or alert).
- **Required negative tests:** Job retries on transient failure; gives up after N attempts and
  records failure; job is idempotent (jti replay cache at RP side already handles double delivery).
- **Files likely involved:** `app/jobs/oidc_backchannel_logout_delivery_job.rb`,
  `app/services/oidc_backchannel_logout_notifier.rb`.

### F-20 — OTP purpose scoping (cross-flow replay)

- **Severity:** P1
- **Status:** NEEDS VERIFICATION
- **Control:** L. OTP / TOTP / email verification
- **Evidence:**
  - `app/models/concerns/otp_lockable.rb:51-97` stores/consumes/clears OTP via shared columns on
    `client_email` / `client_telephone` (`otp_private_key`, `otp_counter`, `otp_expires_at`,
    `otp_attempts_count`, `locked_at`).
  - `app/services/sign_in_otp_resend_service.rb:171` records `purpose=in` in an occurrence/audit
    record. The credential itself has no purpose column observed in the model file.
  - Acceptance/consumption uses `clear_otp` (line 81-91); there is no `purpose==expected_purpose`
    check on the credential at consume time in the concern itself — purpose enforcement (if any)
    depends on the **caller** (which controller/service consumes).
- **Missing evidence:** Whether **every** consume site binds purpose. Specifically: can a sign-up
  OTP for a fresh `client_email` row be used to satisfy a sign-in OTP gate on the same email, and
  vice versa for step-up? Per the user's memory ([[project_sign_acme_boundary_axis]]), Sign =
  credential ceremony, so consume sites are concentrated — they should be enumerated and confirmed.
- **Exploit path:** If any consume path skips purpose binding, an attacker who triggers issuance for
  one purpose can satisfy a gate for another (e.g., step-up reuses a sign-in-issued OTP).
- **Recommended fix:** Either (a) add a `purpose_id` column on the OTP credential and bind purpose
  at issuance + check at consume, or (b) keep separate per-purpose credential rows. Either way, lock
  it down in the concern, not the caller.
- **Required negative tests:** Issue OTP for purpose X; attempt to consume for purpose Y → reject.
- **Files likely involved:** `concerns/otp_lockable.rb`, `client_email.rb`, `client_telephone.rb`,
  all OTP-consuming controllers.

### F-23 — Passkey endpoint rate-limit keyed on IP only

- **Severity:** P2
- **Status:** PARTIAL
- **Control:** N. Rate limiting
- **Evidence:** `app/controllers/sign/app/sign/in/passkey/options_controller.rb:19-38` and the
  verifications sibling use `by: request.remote_ip` only.
- **Missing evidence:** Whether upstream proxy / WAF adds account-aware limiting.
- **Exploit path:** Credential stuffing across many IPs evades pure IP keying. Limited blast radius
  since passkey verify requires a valid stored credential, but enumeration of
  `find_user_by_identifier()` still costs a DB hit.
- **Recommended fix:** Composite key — include normalized identifier when present (e.g.,
  `[request.remote_ip, normalize(params[:identifier])]`).
- **Required negative tests:** Burst on same identifier from multiple IPs trips the per-identifier
  limit.

### F-24 — OTP controller-layer rate limit

- **Severity:** P2
- **Status:** PARTIAL
- **Control:** N. Rate limiting
- **Evidence:** `app/controllers/sign/app/web/v0/in/email/otps_controller.rb:13-16` and telephone
  sibling have no `rate_limit`; rely entirely on `sign_in_otp_resend_policy.rb` (per-target
  backoff).
- **Exploit path:** Per-target backoff still allows large-scale fan-out across many distinct targets
  from a single IP (enumeration / spray).
- **Recommended fix:** Add a defense-in-depth IP `rate_limit` at the controller layer.

### F-26 — MFA recovery codes

- **Severity:** P2
- **Status:** NEEDS VERIFICATION
- **Control:** M. Account recovery
- **Evidence:** `app/services/client_secret_credentials_issue_recovery.rb` exists in the listing;
  storage/consumption semantics not read in this pass.
- **Recommended fix:** Verify hashed (SHA-256+) at-rest, single-use, and revocation-on-use; if
  missing, fix and cover with tests.

### F-29 — Social signup birthdate skip path

- **Severity:** P2
- **Status:** NEEDS VERIFICATION
- **Control:** L/M. Sign-up gates
- **Evidence:** `app/services/social_auth_signup_finalizer.rb:9-10,68-74` accepts birthdate as
  constructor parameter; gating implemented in step gate (`sign_up_step_gate.rb`) which does enforce
  ordering — but a direct POST to `confirmations_controller` may or may not be reachable.
- **Recommended fix:** End-to-end trace of
  `sign_up/check/{apple,google}/{confirmations,birthdates}_controller.rb`, confirming
  `sign_up_step_gate` is invoked before confirmation; add a negative integration test for
  direct-jump.

### F-35 — Operator surface network gate

- **Severity:** P2
- **Status:** NEEDS VERIFICATION
- **Control:** P. Admin/org/network gate
- **Evidence:** `app/controllers/concerns/authentication_operator.rb:19-40` provides operator
  accessors. No `allowlist`/`ip_filter`/mTLS check observed at the controller layer.
- **Recommended fix:** Confirm with infra whether the staff hosts (`sign_staff`, `acme_staff`,
  `core_staff`) are constrained externally. If not, design + add an in-app or load-balancer ACL
  gate, plus a step-up enforcement for dangerous operator actions.

---

## 5. False positives / already mitigated

Items that earlier audit attempts may have flagged but are mitigated in current code:

- **Redirect URI flexible matching** — code does exact-string match
  (`oidc_redirect_uri_validator.rb:7-13`).
- **PKCE plain accepted** — DB constraint allows only S256 (`client_authorization_code.rb:44`);
  validator rejects others (`oidc_authorize_request_validator.rb:34`).
- **Authorization code reuse** — single-use via `consume!` raising on already-consumed/expired
  (`client_authorization_code.rb:97-102`); token endpoint rejects consumed
  (`oidc_token_exchange_service.rb:97`).
- **Refresh token plaintext storage** — stored as SHA3-384 digest
  (`concerns/refresh_token_shared.rb:40-42`).
- **Refresh token rotation race** — row-locked rotate (`concerns/refresh_tokenable.rb:23-66`);
  covered by `refresh_token_concurrency_test.rb`.
- **alg=none accepted** — alg pinned via `JitSecurityJwtRegistry::ALGORITHM` check before decode
  (`oidc_client_assertion_jwt.rb:33`).
- **Issuer derived from request.host** — derived from immutable boot config
  (`oidc_issuer.rb:46-54`); host header validated by `config.hosts` whitelist
  (`production.rb:117-128`).
- **Backchannel logout token unsigned / unvalidated** — full validation in
  `oidc_logout_token_codec.rb:78-103` plus jti replay cache.
- **Logout does not revoke refresh tokens** — `authentication_logout_all_sessions.rb:33-79` iterates
  tokens and revokes, plus bumps `session_version`.
- **CSRF disabled on OAuth endpoints** — no `skip_forgery_protection` hit; backchannel uses
  `:null_session` correctly.
- **Replay store stored in Rails.cache for ceremonies** — actually DB-backed for
  passkey/step-up/totp transactions.
- **TOTP secret plaintext** — `encrypts :private_key` in `client_totp_credential.rb:37`.

---

## 6. Passes with good evidence

| Control                                                           | Evidence                                                                                                                                                           |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Authorization code lifecycle (TTL, single-use, bindings)          | `client_authorization_code.rb:35,44,76,85-102,108-116`; `oidc/token_exchange_service_test.rb`                                                                      |
| PKCE mandatory + S256-only + constant-time                        | `oidc_authorize_request_validator.rb:33-34`; `client_authorization_code.rb:44,108-116`; `oidc/authorize_service_test.rb`                                           |
| Grant-type allowlist                                              | `oidc_token_exchange_service.rb:55-57`                                                                                                                             |
| alg/kid pinning                                                   | `oidc_client_assertion_jwt.rb:33,39`                                                                                                                               |
| Refresh-token rotation + reuse + family revoke                    | `acme_refresh_token_service.rb`, `concerns/refresh_tokenable.rb`; `refresh_token_concurrency_test.rb`, `security/invariants/refresh_token_reuse_invariant_test.rb` |
| Refresh-token at-rest digest                                      | `concerns/refresh_token_shared.rb:40-42`                                                                                                                           |
| OIDC issuer integrity                                             | `oidc_issuer.rb:46-54`; `production.rb:117-128`; `oidc_issuer_test.rb`                                                                                             |
| Backchannel logout token validation + jti replay cache            | `oidc_logout_token_codec.rb:78-114`; `rp_logout_receivers_test.rb`                                                                                                 |
| id_token_hint + post_logout_redirect_uri validation               | `oidc_end_session_request.rb:29-69,111-123`                                                                                                                        |
| Logout-request jti replay                                         | `oidc_logout_request.rb:20-24,85-103`                                                                                                                              |
| Refresh-token revocation on logout / session-version bump         | `authentication_logout_all_sessions.rb:33-79`; `authentication_logout_current_session.rb:20-37`                                                                    |
| TOTP secret encryption                                            | `client_totp_credential.rb:37`                                                                                                                                     |
| Ceremony replay stores are DB-backed                              | `identity_{passkey,step_up,totp}_ceremony_replay_store.rb`                                                                                                         |
| WebAuthn rp_id/origin pinning                                     | `concerns/sign_webauthn.rb:26-70`                                                                                                                                  |
| Passkey challenge replay protection                               | `concerns/sign_webauthn.rb:208-253`                                                                                                                                |
| OTP attempt lockout                                               | `concerns/otp_lockable.rb:34-36,128-147`                                                                                                                           |
| OTP resend backoff                                                | `sign_in_otp_resend_policy.rb:12-34`                                                                                                                               |
| Step-up freshness binding                                         | `identity_step_up_ceremony_freshness_committer.rb:43-72`                                                                                                           |
| Sign-up step ordering                                             | `sign_up_step_gate.rb:26-111`                                                                                                                                      |
| Chronicle/observability redaction                                 | `chronicle_recorder.rb:5-19`; `observability_redactor.rb`                                                                                                          |
| Audit append-only design                                          | `identity_audit.rb:5-43`; `authentication/audit_writer_test.rb`                                                                                                    |
| Email at-rest encryption (with documented deterministic tradeoff) | `concerns/email.rb:39-40`                                                                                                                                          |
| OmniAuth callback origin whitelist                                | `config/initializers/omniauth.rb:47-103`                                                                                                                           |

---

## 7. Audit reliability blockers

Separate from security findings:

- Working tree dirty (many M/A files, including new OIDC service classes and `db/*_structure.sql`
  dumps). Static analysis pinned to the working-tree files as-read; if a finding cites a new file
  (`oidc_redirect_uri_validator.rb`, `oidc_client_secret_resolver.rb`,
  `oidc_client_stores_static_client_store.rb`), the citation reflects pre-commit state.
- Test-DB partial bootstrap (`Schema migrations table does not exist yet` for one DB in the test
  family). Targeted tests cited above may need `bin/rails db:test:prepare` to run cleanly. Does not
  affect static evidence.
- No tests were executed in this pass (read-only contract). Test-coverage column is based on file
  listing + spot reading of test descriptions, not actual runs.
- No prior finding IDs were carried forward.

---

## 8. Recommended next pass

Pick **at most 3** items (rules: not broad rewrites):

1. **F-01 — Rate-limit `com` and `org` `/oauth/authorize`** by mirroring the app controller's
   `rate_limit(by: [ip, client_id])` block. Add the two negative tests. Smallest blast radius, P1
   closure.
2. **F-02 — Add jti replay cache to private_key_jwt** (`OidcClientAssertionJwt.decode!` or its
   caller) using the existing Rails.cache pattern from `oidc_logout_token_codec.rb`. Add a replay
   test. P1 closure.
3. **F-20 — Confirm and lock OTP purpose binding** at the concern layer (`otp_lockable.rb`). Either
   thread a required `purpose` argument through `store_otp` / `clear_otp` and verify on consume, or
   add a `purpose_id` column. Add a cross-purpose-replay negative test. P1 closure on a NEEDS
   VERIFICATION item that, if exploitable, is the most serious finding in this report.

Defer to a later pass: F-03 (registration validator hardening), F-13 (backchannel retry/DLQ),
F-23/F-24 (composite rate-limit keys), F-26 (recovery code semantics), F-29 (birthdate skip path),
F-35 (operator network gate). These are P2/NEEDS VERIFICATION and merit their own scoped patches.

---

## Verification (how to use this report)

- The plan file is the audit report. No code changes are part of this pass.
- To re-run the audit: re-list routes (`bin/rails routes`), re-grep the cited files, and compare to
  the citation columns in §3 and §4.
- To validate one finding before acting (e.g., F-02), read
  `app/services/oidc_client_assertion_jwt.rb`, `oidc_client_registry.rb#authenticate_assertion`, and
  `oidc_token_exchange_service.rb` end-to-end and grep for `Rails.cache` on the assertion path;
  absence confirms.
- Before implementing F-20, run `bin/rails test test/concerns/common_otp_test.rb` and grep
  `clear_otp` / `store_otp` callers under `app/controllers/sign/**` and `app/services/sign_*` to
  enumerate consume sites.
