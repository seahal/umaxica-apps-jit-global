# Browser Flow State Inventory

Date: 2026-11-06

Status: Work order 1 inventory. This document records current behavior and proposed target shapes;
it does not authorize or describe an implementation. The accepted contract is
specs/browser-flow-state-cookies/spec.md.

## Scope and method

The source scan covered Ruby files under app/ and lib/, including direct session[...] access,
request.session[...], @session[...], `session.dig` and `session.key?` reads, dynamic-key accessors,
`session.delete`, and Rails session reset paths. Constants and their callers were followed to identify
concrete keys and surfaces. Several
occurrences are not Rails-session access: session[:revoke] in the identity session views reads a
local serialized hash, session[:literal_key] is comment text, and session.update! in persistence
code updates an Active Record session row. They are excluded.

Rails currently stores the whole host-local session in its encrypted cookie for 14 days. A shorter
application deadline listed below does not shorten the browser cookie's lifetime: it is only checked
by the current reader. Unless noted otherwise, absent state follows the caller's ordinary
first-entry or restart path, while malformed state either becomes absent or is refused by that
reader. The current Rails cookie protects integrity/confidentiality but does not provide a
per-purpose expiry or cross-purpose binding.

The Flow ID column describes where O-3b's random, single-use ID must exist after migration. Where
the current code has only a client-side/session value, the proposed server record is an explicit
design dependency, not an assertion that such a record exists today. For O-3c, the lock must be
inside the named server-side transition/consume writer and held while it checks and commits the
checkpoint.

## Key-by-key contract map

Each concrete key (and each dynamic accessor name) has its own entry below. The named detailed
contract row supplies the flow/surface, record and current lifetime, failure behavior, intended
lifetime, proposed cookie/JSON, O-3b flow-ID owner, and O-3c lock/checkpoint. The direct access-site
index supplies the exact read/write/delete paths for the key expression. This cross-reference keeps
identical lifecycle facts consistent for keys that share one owner.

| Key / dynamic accessor                            | Detailed contract                           |
| ------------------------------------------------- | ------------------------------------------- |
| `app_sign_in_flow_locator`                        | Credential sign-in locators                  |
| `org_sign_in_flow_locator`                        | Credential sign-in locators                  |
| `sign_in_sequence`                                | Post-authentication sequence     |
| `app_sign_in_sequence`                            | Post-authentication sequence     |
| `com_sign_in_sequence`                            | Post-authentication sequence     |
| `org_sign_in_sequence`                            | Post-authentication sequence     |
| `sign_in_checkpoint`                              | Sign-in bulletin        |
| `app_sign_up_flow_locator`                        | APP sign-up flow locator                         |
| `auth_app_up_sequence_id`                         | APP sign-up state and contact proof        |
| `sign_up_flow_id`                                 | APP sign-up state and contact proof        |
| `sign_up_email_flow_state`                        | APP sign-up state and contact proof                     |
| `user_telephone_registration`                     | APP sign-up state and contact proof           |
| `user_telephone_otp_last_sent_at`                 | APP sign-up state and contact proof           |
| `sign_up_existing_email_id`                       | APP sign-up state and contact proof           |
| `sign_up_existing_email_skip_otp`                 | APP sign-up state and contact proof           |
| `sign_up_sequence_session_key`                    | APP sign-up state and contact proof               |
| `sign_up_telephone_registration_session_key`      | APP sign-up state and contact proof               |
| `sign_app_in_email_authentication`                | APP email sign-in and send cooldown      |
| `sign_in_email_cooldown_address`                  | APP email sign-in and send cooldown             |
| `sign_in_email_cooldown_at`                       | APP email sign-in and send cooldown             |
| `user_email_authentication_pt`                    | Return target and browser nonce                       |
| `authentication_pt_nonce`                         | Return target and browser nonce               |
| `authentication_return_target_nonce`              | Return target and browser nonce               |
| `pending_mfa`                                     | MFA continuation                            |
| `mfa_user_id`                                     | MFA continuation                            |
| `external_authentication_ceremony_reference`      | Legacy cleanup-only keys               |
| `session_limit_gate`                              | Session-limit resolution               |
| `app_sign_in_welcome`                             | One-shot welcome gate                       |
| `com_sign_in_welcome`                             | One-shot welcome gate                       |
| `org_sign_in_welcome`                             | One-shot welcome gate                       |
| `sign_in_welcome`                                 | One-shot welcome gate                       |
| `social_auth_intent`                              | Social login/link/callback state        |
| `social_auth_user_id`                             | Social login/link/callback state        |
| `social_auth_started_at`                          | Social login/link/callback state        |
| `social_auth_flow_id`                             | Social login/link/callback state        |
| `social_auth_provider`                            | Social login/link/callback state        |
| `social_auth_pt`                                  | Social login/link/callback state        |
| `social_auth_entry`                               | Social login/link/callback state        |
| `social_auth_ri`                                  | Social login/link/callback state        |
| `social_admission_ceremony_session_id`            | Social login/link/callback state        |
| `social_ceremony_grant`                           | Social login/link/callback state        |
| `social_link_completion`                          | Social login/link/callback state        |
| `social_auth_nonce`                               | Social login/link/callback state        |
| `social_auth_state`                               | Social login/link/callback state        |
| `social_auth_state_started_at`                    | Social login/link/callback state        |
| `social_auth_state_used_at`                       | Social login/link/callback state        |
| `social_auth_state_provider`                      | Social login/link/callback state        |
| `omniauth.state`                                  | OmniAuth and provider state                    |
| `omniauth.nonce`                                  | OmniAuth and provider state            |
| `omniauth.pkce.verifier`                          | OmniAuth and provider state            |
| `auth_org_entra_omniauth_pt`                      | Return target and browser nonce                     |
| `oidc_pending_flows`                              | RP-initiated OIDC authorization                  |
| `oidc_code_verifier`                              | Legacy cleanup-only keys                    |
| `oidc_state`                                      | Legacy cleanup-only keys                    |
| `oidc_nonce`                                      | Legacy cleanup-only keys                    |
| `oidc_pt`                                         | Legacy cleanup-only keys                    |
| `oidc_max_age`                                    | Legacy cleanup-only keys                    |
| `oidc_logout_request`                             | RP-initiated logout                                 |
| `oidc_logout_completed`                           | RP-initiated logout                                 |
| `email_registration_public_id`                    | APP and ORG contact registration                 |
| `email_registration_transaction_ref`              | APP and ORG contact registration                 |
| `email_registration_pt`                           | APP and ORG contact registration                 |
| `settings_telephone_registration_id`              | APP and ORG contact registration             |
| `settings_telephone_registration_transaction_ref` | APP and ORG contact registration             |
| `staff_email_registration_public_id`              | APP and ORG contact registration                 |
| `staff_email_registration_transaction_ref`        | APP and ORG contact registration                 |
| `staff_telephone_registration_id`                 | APP and ORG contact registration             |
| `registration_session_key`                        | APP and ORG contact registration |
| `registration_transaction_session_key`            | APP and ORG contact registration |
| `base_step_up_marker_locator`                     | Base step-up and admission browser binding                                |
| `base_step_up_conflict`                           | Base step-up and admission browser binding                                |
| `auth_admission_browser_nonce`                    | Base step-up and admission browser binding                   |
| `enforcement_recovery_reentry`                    | Recovery and withdrawal re-entry                |
| `withdrawal_ceremony_reentry`                     | Recovery and withdrawal re-entry                |
| `passkey_challenges`                              | WebAuthn challenges                         |
| `org_normal_sign_in_transaction`                  | ORG Entra-then-credential continuation             |
| `sign_out_notice`                                 | Sign-out notice                             |
| `client_secret_operation`                         | Secret issuance and credential retry               |
| `staff_secret_credential_raw`                     | Secret issuance and credential retry                 |
| `secret_credential_ceremony`                      | Legacy cleanup-only keys              |
| `totp_enrollment`                                 | Legacy cleanup-only keys              |
| `totp_ceremony`                                   | Legacy cleanup-only keys              |
| `private_key`                                     | Legacy cleanup-only keys              |
| `timezone`                                        | Preference session values                    |
| `language`                                        | Preference session values                    |
| `inertia_clear_history`                           | Rails-session exceptions             |
| `_csrf_token`                                     | Rails-session exceptions                        |
| `email_registration_pt_session_key` | APP and ORG contact registration |
| `registration_email_session_key` | APP and ORG contact registration |
| `welcome_gate_key` | One-shot welcome gate |
| `surface_key` | Credential sign-in locators |
| `key_for(surface)` | Post-authentication sequence |
| `session_key` | Dynamic session-key resolution |
| `load_session_record(session_key)`                | Dynamic accessor with no known caller         |

## Detailed contract profiles

The key-by-key index above maps every key to one profile. Exact writer, reader and deletion paths
are in the direct access-site index below. Current application deadlines do not expire the Rails
cookie itself: the host-local encrypted Rails session lasts 14 days unless reset.

### Credential sign-in locators

- Keys: `app_sign_in_flow_locator`, `org_sign_in_flow_locator`.
- Flow/surface: credential sign-in on Auth/Visa APP and ORG hosts.
- Server authority: `ClientSignInFlow` or `OperatorSignInFlow`; each has expiry and terminal state.
- Current failure: missing, unknown, terminal or binding mismatch yields no current flow/refusal;
  malformed locator fields are treated as absent when `KeyError` is rescued.
- Intended lifetime: exactly the owning sign-in flow expiry.
- Target: `__Host-umaxica-sign-in`; JSON has `flow_id` and `binding_digest` only. The host
  determines the surface, so no surface field is needed.
- O-3b/O-3c: flow public ID and nonce digest live on the server flow row. Lock that row at the
  first committed transition past entry/primary-pending; exact transition varies by sign-in method.

### Post-authentication sequence

- Keys: `sign_in_sequence`, `app_sign_in_sequence`, `com_sign_in_sequence`,
  `org_sign_in_sequence`; dynamic `key_for(surface)` and `surface_key`.
- Flow/surface: post-authentication sign-in sequence on Auth/Visa APP/COM/ORG callers.
- Server authority: no server row found. Current payload contains ID, actor, step and references;
  it has a 15-minute logical TTL.
- Current failure: absent payload is blank; malformed/expired payload is rejected by sequence gates.
  The legacy generic key is copied to a surface key then deleted.
- Intended lifetime: create a server sequence record with 15-minute expiry, capped by parent flow.
- Target: fold into sign-in cookie only if the sign-in row owns the sequence; otherwise use
  `__Host-umaxica-sign-in-sequence` with `flow_id` and opaque `sequence_ref`.
- O-3b/O-3c: bind ID to a server sign-in/sequence row. Lock parent flow at the first transition
  beyond entry; cookie is never the winner record.

### Sign-in bulletin

- Key: `sign_in_checkpoint` (`AuthenticationBase::BULLETIN_SESSION_KEY` /
  `AuthIoKeys::Session::CHECKPOINT`).
- Flow/surface: one-shot sign-in bulletin on Auth/Visa APP and ORG.
- Server authority: Client/Operator-owned bulletin; current timeout is 2 hours.
- Current failure: missing/unknown bulletin renders no bulletin; expired or malformed state is
  cleared when consumed.
- Intended lifetime: 2 hours, matching the server bulletin.
- Target: `__Host-umaxica-sign-in-bulletin` with `flow_id`, `bulletin_ref`, `issued_at`.
- O-3b/O-3c: ID belongs to sign-in flow. Lock bulletin read-state and sign-in flow at completion;
  determine from transition inventory whether display is itself the checkpoint.

### APP sign-up flow locator

- Key: `app_sign_up_flow_locator`.
- Flow/surface: Auth APP sign-up.
- Server authority: `ClientSignUpFlow`, bound to `ClientAuthAdmissionBinding` and Auth ceremony;
  lifecycle uses configured expiry/cleanup.
- Current failure: absent may start a newly admitted flow; malformed/foreign owner is refused;
  terminal unreleased flow can remain blocked until cleanup.
- Intended lifetime: `ClientSignUpFlow.expires_at`.
- Target: `__Host-umaxica-sign-up` with `flow_id`, `binding_digest` and an opaque server
  transaction ref where the current key points to a child transaction.
- O-3b/O-3c: flow public ID stays on the row; lock admission binding/flow at the first transition
  beyond STARTED, exact step from accepted sign-up transition writer.

### APP sign-up state and contact proof

- Keys: `auth_app_up_sequence_id`, `sign_up_flow_id`, `sign_up_email_flow_state`,
  `user_telephone_registration`, `user_telephone_otp_last_sent_at`, `sign_up_existing_email_id`,
  `sign_up_existing_email_skip_otp`; dynamic sign-up key methods.
- Flow/surface: Auth APP sign-up email/telephone sequence and OTP.
- Server authority: `ClientSignUpFlow`, pending contact/OTP records, and `ClientEmail` for existing ID.
  No separate server record currently owns the email state enum, send timestamp or skip boolean.
- Current failure: absent sequence means no sequence; absent telephone state restarts/refuses that step;
  invalid OTP is rejected by OTP writer; email state normalizes to `init`; restart clears existing-email
  markers. `sign_up_flow_id` is a read-only observability fallback with no app/lib writer found.
- Intended lifetime: sign-up flow expiry; contact/OTP state follows its transaction expiry; send
  cooldown exists only through configured cooldown; fallback key has no target lifetime until producer
  is confirmed.
- Target: `__Host-umaxica-sign-up` with flow and server transaction references. Keep contact values,
  OTP data and skip decision server-side.
- O-3b/O-3c: ID on `ClientSignUpFlow`. Lock flow/admission for contact issue/verification; OTP
  attempt remains authoritative for rate and verification outcomes.

### APP email sign-in and send cooldown

- Keys: `sign_app_in_email_authentication`, `sign_in_email_cooldown_address`,
  `sign_in_email_cooldown_at`.
- Flow/surface: Auth APP email sign-in.
- Server authority: email OTP/Auth ceremony for active OTP; no record owns the session cooldown pair.
  Dummy authentication path currently keeps submitted address in session.
- Current failure: missing email state cannot continue OTP; malformed ID/address fails later lookup;
  cooldown is inactive when address/time missing and malformed time parses as inactive. Address may
  remain in session after abandonment.
- Intended lifetime: OTP/Auth ceremony expiry; cooldown only `EmailOtpPolicy::SEND_COOLDOWN`.
- Target: `__Host-umaxica-sign-in-email` with JSON `{ "flow_id": "…", "ceremony_ref": "…",
  "attempt_ref": "…" }` when an attempt ref is needed; no address, token or OTP in cookie.
- O-3b/O-3c: server sign-in flow and OTP attempt carry flow ID. Lock OTP attempt on issuance and
  evidence commit.

### Return target and browser nonce

- Keys: `user_email_authentication_pt`, `auth_org_entra_omniauth_pt`,
  `authentication_pt_nonce`, `authentication_return_target_nonce`;
  dynamic `preserve_pt` session-key argument defaults to `user_email_authentication_pt`.
- Flow/surface: redirect continuation across Auth/Visa/Base hosts, plus Auth ORG Entra callback.
- Server authority: no general PT record; signed request PT is validated. Nonces currently have no
  separate row. ORG Entra callback consumes/deletes its session PT.
- Current failure: consumed PT is deleted; missing uses caller default; malformed/untrusted target
  is rejected/sanitized; missing nonce is generated; invalid binding falls back/refuses.
- Intended lifetime: parent flow/admission expiry; safe return reference consumed earlier.
- Target: `__Host-umaxica-return-target` with `flow_id`, server `return_ref`, and binding digest.
- O-3b/O-3c: parent flow stores flow ID, safe path and nonce digest. Lock it when accepting the first
  bound continuation.

### MFA continuation

- Keys: `pending_mfa`, `mfa_user_id`.
- Flow/surface: Auth APP/ORG sign-in.
- Server authority: actor MFA credential/status and parent flow; no dedicated browser MFA challenge
  row found for this session payload.
- Current failure: missing/malformed actor or MFA context refuses; both keys are cleared on refusal
  and completion.
- Intended lifetime: MFA challenge expiry, capped by parent sign-in flow.
- Target: `__Host-umaxica-mfa` with `flow_id` and server `challenge_ref`; no actor ID or MFA payload.
- O-3b/O-3c: challenge/flow owns ID. Lock while consuming successful evidence; first valid
  transition wins.

### Session-limit resolution

- Key: `session_limit_gate` (`SessionLimitGate::GATE_SESSION_KEY`).
- Flow/surface: Auth/Visa APP and ORG sign-in continuation.
- Server authority: Client/Operator sign-in flow and `SessionLimitResolutionTransaction`.
- Current failure: embedded TTL is 15 minutes; invalid/consumed paths delete it; missing, expired,
  malformed or bad nonce redirects/refuses.
- Intended lifetime: transaction expiry, capped by parent sign-in flow.
- Target: `__Host-umaxica-session-limit` with JSON `{ "flow_id": "…", "resolution_ref": "…", "binding_digest": "…" }`.
- O-3b/O-3c: ID on parent and child record. Lock both while selected-session resolution commits.

### One-shot welcome gate

- Keys: `app_sign_in_welcome`, `com_sign_in_welcome`, `org_sign_in_welcome`, `sign_in_welcome`;
  dynamic `welcome_gate_key`.
- Flow/surface: Auth/Visa APP/COM/ORG.
- Server authority: parent sign-in flow when sequence ID exists; no separate gate row today.
- Current failure: embedded expiry/remaining-count/sequence mismatch clears gate and returns false;
  missing means welcome is skipped.
- Intended lifetime: shortest server-backed expiry that allows the next welcome transition.
- Target: fold into sign-in cookie only when that flow row owns it; otherwise a dedicated welcome
  cookie with `flow_id` and one-shot server gate ref.
- O-3b/O-3c: sign-in flow ID; lock the row while the welcome checkpoint is consumed atomically.

### Social login/link/callback state

- Keys: `social_auth_intent`, `social_auth_user_id`, `social_auth_started_at`,
  `social_auth_flow_id`, `social_auth_provider`, `social_auth_pt`, `social_auth_entry`,
  `social_auth_ri`, `social_admission_ceremony_session_id`, `social_ceremony_grant`,
  `social_link_completion`, `social_auth_nonce`, `social_auth_state`,
  `social_auth_state_started_at`, `social_auth_state_used_at`, `social_auth_state_provider`.
- Flow/surface: Auth APP login/link/step-up callbacks; Auth ORG Entra entry as applicable.
- Server authority: `SocialAuthCallbackStateStore` (5-minute state); APP also has
  `ClientSocialCeremonyTransaction`, `ClientVisaSocialLinkAdmission`, Auth ceremony and OIDC
  grant/admission records. ORG uses Operator/Entra identity and Auth ceremony. Some intent/PT/entry/RI
  values do not have separate records today.
- Current failure: missing grant/admission ref blocks callback commit; state/provider mismatch refuses
  callback; stale social state is rejected; abandonment may leave auxiliary keys until session reset.
  Apple nonce is one-attempt state. Step-up/admission records may live 10 minutes.
- Intended lifetime: each cookie equals its owning social transaction; state currently 5 minutes and
  step-up/admission may be 10 minutes. Do not group unlike expiry records in one cookie.
- Target: `__Host-umaxica-social-sign-in` and `__Host-umaxica-social-link`, one cookie per purpose,
  each with `flow_id`, Auth ceremony ref, state ref and allowlisted provider only. PT/entry/RI/actor remain server-side.
- O-3b/O-3c: persist the random flow ID on the social transaction/ORG ceremony row. Lock transaction
  and callback state while authenticated evidence or identity link commits.

### OmniAuth and provider state

- Keys: `omniauth.state`, `omniauth.nonce`, `omniauth.pkce.verifier`.
- Flow/surface: Auth APP Google/Apple and Auth ORG Entra round trips.
- Server authority: OmniAuth gem owns state; application owns Google nonce and Entra PKCE verifier.
  Provider attempt needs a server transaction for nonce/verifier.
- Current failure: missing/mismatched state is rejected by gem callback; nonce/verifier are one-attempt
  values but can survive abandoned attempts until Rails session expiry/reset.
- Intended lifetime: state remains under Rails session contract; nonce/verifier match provider attempt
  transaction expiry.
- Target: only `omniauth.state` remains in Rails session (O-1); other values reference provider
  server transaction and are not cookie plaintext.
- O-3b/O-3c: provider transaction owns flow ID, verifier and nonce/digest. Lock and consume it at
  callback acceptance; compare gem state to that transaction.

### RP-initiated OIDC authorization

- Keys: `oidc_pending_flows`; cleanup-only `oidc_code_verifier`, `oidc_state`, `oidc_nonce`,
  `oidc_pt`, `oidc_max_age`.
- Flow/surface: Base/Warp/Core/Palm/Tech/Edit and applicable Visa RP hosts.
- Server authority: Visa authorization transaction keyed by JTI/state and client registration/result.
  Current TTL equals `OidcStateJwt::TTL`; pending payload includes code verifier, nonce and created_at.
- Current failure: unknown state produces no flow; expired entries are removed/refused; valid state is
  consumed once. The five older keys are delete-only in current code.
- Intended lifetime: Visa transaction expiry; callback consumes at most once.
- Target: `__Host-umaxica-oidc-authorization` with transaction `flow_id` and opaque transaction ref;
  verifier, nonce, PT/target and max_age stay server-side.
- O-3b/O-3c: Visa authorization row owns flow ID and verifier/nonce. Lock it through callback
  consume, code exchange and final outcome commit.

### RP-initiated logout

- Keys: `oidc_logout_request`, `oidc_logout_completed`.
- Flow/surface: Visa APP/ORG and RP callers.
- Server authority: `OidcEndSessionRequest` tied to device session; logout operation revokes session.
- Current failure: missing/invalid request renders explicit failure/already-signed-out path;
  completed marker is boolean and cleared/replaced during logout. Browser/device mismatch refuses.
- Intended lifetime: request expiry; completion marker only for immediate post-logout presentation.
- Target: `__Host-umaxica-oidc-logout` with JSON `{ "flow_id": "…", "logout_ref": "…" }`.
- O-3b/O-3c: logout row/device session owns ID. Lock session revocation writer; consume once.

### APP and ORG contact registration

- Keys: `email_registration_public_id`, `email_registration_transaction_ref`, `email_registration_pt`,
  `settings_telephone_registration_id`, `settings_telephone_registration_transaction_ref`,
  `staff_email_registration_public_id`, `staff_email_registration_transaction_ref`,
  `staff_telephone_registration_id`, and dynamic `registration_session_key`,
  `registration_transaction_session_key`, `registration_email_session_key`,
  `email_registration_pt_session_key`.
- Flow/surface: signed-in Base APP and ORG email/telephone registration.
- Server authority: APP ClientEmail/ClientTelephone and ORG OperatorEmail/OperatorTelephone ceremony
  transaction rows; each has its own expiry and actor/session/browser binding.
- Current failure: missing, stale or corrupt ref fails form/OTP/commit validation or restarts; browser
  binding and transaction expiry are rechecked before writes. PT is consumed once. The literal key
  `settings_telephone_registration_transaction_ref` is used by APP and ORG, isolated by host sessions.
- Intended lifetime: the exact corresponding ceremony transaction expiry.
- Target: separate host-local cookies `__Host-umaxica-email-registration` and
  `__Host-umaxica-telephone-registration`, each with JSON `{ "flow_id": "…",
  "transaction_ref": "…" }`; public identifiers and PT stay server-side.
- O-3b/O-3c: each ceremony transaction ID is the flow ID. Lock at OTP verification and final
  credential commit; final commit is checkpoint.

### Base step-up and admission browser binding

- Keys: `base_step_up_marker_locator`, `base_step_up_conflict`, `auth_admission_browser_nonce`.
- Flow/surface: Base APP/ORG step-up and Base-to-Auth admission.
- Server authority: admission transaction and AuthAdmissionBinding; auth-state marker store is
  transaction-bound. Conflict payload currently repeats requirements/actor/session metadata.
- Current failure: absent/invalid nonce or marker mismatch rejects; conflict payload clears on
  continue/cancel; new admission rotates nonce.
- Intended lifetime: exact owning admission/step-up transaction expiry.
- Target: separate `__Host-umaxica-step-up` and `__Host-umaxica-admission` cookies with flow ID and
  transaction/marker ref; requirements and actor/session bindings stay server-side.
- O-3b/O-3c: admission/transaction row owns ID. Lock it at first admitted transition/evidence commit;
  racing tabs cannot decide via cookie state.

### Recovery and withdrawal re-entry

- Keys: `enforcement_recovery_reentry`, `withdrawal_ceremony_reentry`.
- Flow/surface: owning Auth/Base enforcement recovery and withdrawal surfaces.
- Server authority: recovery/withdrawal ceremony record; some values contain IDs/digests without a
  clear owning transaction for every path.
- Current failure: malformed/missing values restart/refuse; completion and invalid proof delete them.
- Intended lifetime: exact recovery/withdrawal ceremony expiry.
- Target: separate purpose cookies with JSON `{ "flow_id": "…", "ceremony_ref": "…" }`; no email ID/contact value.
- O-3b/O-3c: each ceremony row owns the ID. Lock its first successful proof/transition commit.

### WebAuthn challenges

- Key: `passkey_challenges` (`Webauthn::ChallengeStore`).
- Flow/surface: same-session Auth/Base passkey registration, authentication, emergency and step-up XHR.
- Server authority: no server row; map of up to 5 challenges lives in session, each with 10-minute TTL.
- Current failure: missing/expired challenge raises a specific error; malformed map is empty;
  consume deletes before purpose/RP ID/origin/actor validation, so mismatch burns challenge.
- Intended lifetime: 10 minutes per challenge.
- Target: `__Host-umaxica-webauthn` with JSON `{ "flow_id": "…", "challenge_ref": "…" }`; move challenge
  and binding to server store first.
- O-3b/O-3c: challenge record owns ID; atomic consume under lock precedes validation/commit.

### ORG Entra-then-credential continuation

- Keys: `org_normal_sign_in_transaction`, `auth_org_entra_omniauth_pt` is separately listed above.
- Flow/surface: Auth ORG.
- Server authority: no durable transaction row; session payload holds Operator ID, Entra ID, PT, RI,
  status and 10-minute expiry. Chronicle is created only on halt.
- Current failure: missing/invalid/halted/expired payload refuses; consume deletes before second factor
  or session establishment.
- Intended lifetime: 10 minutes or the new Auth-owned transaction's shorter expiry.
- Target: `__Host-umaxica-org-sign-in` with flow ID and server ceremony ref; no actor, PT or Entra ID.
- O-3b/O-3c: create/use durable Auth ceremony transaction with flow ID; lock when Entra identity is
  committed and when selected credential consumes continuation.

### Sign-out notice

- Key: `sign_out_notice` (`SignOutNotice`).
- Flow/surface: Auth/Visa/Base callers.
- Server authority: Valkey notice store, TTL 5 minutes; payload contains actor/session/state/face.
- Current failure: session locator is deleted before store resolution; missing/expired store suppresses
  notice; Valkey errors fail closed.
- Intended lifetime: 5 minutes, matching the Valkey record.
- Target: `__Host-umaxica-sign-out-notice` with opaque notice `flow_id` and ref.
- O-3b/O-3c: notice store ID is flow ID; Valkey atomic consume is the one-shot serialization point.

### Secret issuance and credential retry

- Keys: `client_secret_operation`, `staff_secret_credential_raw`.
- Flow/surface: Base APP secret issuance and Base ORG credential creation.
- Server authority: APP `ClientSecretIssuance` has UUID operation ID and explicit state/expiry. ORG
  creates the raw credential only after Turnstile and the create request succeed (I-5); it has no
  retry candidate.
- Current failure: invalid/finished APP locator rotates or refuses; Base ORG keeps the generated raw
  credential in `staff_secret_credential_raw` across Turnstile retry and in the Rails cookie.
- Intended lifetime: APP issuance expiry; ORG raw credential exists only for the successful response
  that discloses it once.
- Target: APP `__Host-umaxica-secret-issuance` with JSON `{ "flow_id": "…", "operation_ref": "…" }`.
  ORG has no flow cookie or server-side raw-secret retry state; remove the session key in the
  implementation stage.
- O-3b/O-3c: APP issuance row owns its ID. ORG has no retry checkpoint or candidate row; create is
  committed only after Turnstile succeeds.

### Legacy cleanup-only keys

- Keys: `external_authentication_ceremony_reference`, `oidc_code_verifier`, `oidc_state`,
  `oidc_nonce`, `oidc_pt`, `oidc_max_age`, `secret_credential_ceremony`, `totp_enrollment`,
  `totp_ceremony`, `private_key`, and `sign_up_flow_id` fallback.
- Flow/surface: old Auth/OIDC/TOTP cleanup and sign-up observability.
- Server authority: no active app/lib producer/consumer was found for exact cleanup-only keys.
- Current failure/lifetime: stale values can remain for Rails 14-day cookie lifetime unless reset/cleanup;
  no active continuation behavior was found. `sign_up_flow_id` has a read-only fallback only.
- Intended lifetime: none for confirmed dead state; confirm out-of-tree producers before removal.
- Target: no purpose cookie unless an active owner is found; do not implement compatibility for dead keys.
- O-3b/O-3c: no current flow ID/checkpoint can be assigned.

### Preference session values

- Keys: `timezone`, `language`.
- Flow/surface: shared preference update/request setup.
- Server authority: Actor preference record; app/lib writes the session values but no direct app/lib
  session reader was found. Missing/corrupt value has no observed direct-session behavior.
- Current lifetime: Rails cookie 14 days. Existing Preference cookies are explicitly outside this spec.
- Intended lifetime/target: prefer persisted preference as source and no authentication-flow cookie;
  confirm out-of-tree readers and the scope conflict before deleting session copies. If a cookie is
  required, existing Preference-cookie scope needs a separate owner decision.
- O-3b/O-3c: these are not authentication flows; applicability of required random flow ID is unresolved.
  Do not invent an ID or checkpoint.

### Rails-session exceptions

- `_csrf_token`: implicit Rails CSRF middleware state, not an app/lib `session[...]` call. Keep in
  Rails session under D-10; middleware creates/validates it and missing/invalid token follows Rails
  CSRF rejection behavior. Lifetime follows host session config (14 days).
- `omniauth.state`: OmniAuth gem-managed state. Keep in Rails session under O-1; missing/mismatched
  state is rejected by the gem. It must still correlate with the provider server transaction.
- `inertia_clear_history`: Auth/Base/Visa/Warp navigation flag. Keep in Rails session under O-2;
  readers accept only literal true, missing/malformed means false. No app/lib delete was found, so it
  can remain set until session reset; no new per-purpose expiry is proposed.

### Dynamic session-key resolution

- Expression: `session[session_key]` in `SignInCycleLocator`, `SignUpCycleLocator` and
  `AuthenticationRedirects`; these resolve to the concrete keys listed in the key-by-key map.
- Flow/surface and current lifetime/failure: inherit the resolved sign-in locator, sign-up locator or
  return-target profile; this expression does not introduce another persisted key.
- Target, O-3b and O-3c: inherit the resolved key's purpose cookie, server flow ID and locked
  checkpoint. Keep each resolution explicit in its owner; do not serialize the Ruby method name.

### Dynamic accessor with no known caller

- `load_session_record(session_key)` reads a caller-supplied session key in AuthenticationBase.
- No call site in app/lib was found; without a concrete key/flow the owner, lifetime, target cookie,
  O-3b flow ID and O-3c checkpoint cannot be assigned. Resolve out-of-tree use before migration.

## Direct access-site index (app/ and lib/)

The key map and profiles above cross-reference this index. It lists non-comment bracket, `dig`, and
`key?` reads, assignments and `session.delete(...)` calls under app/ and lib/, with its current path and line.
A `write` is syntactic assignment; a `read` is a non-assignment access; `delete` clears state.
Dynamic expressions (for example `session_key`, `surface_key`, or a constant) resolve through the
owner named in the purpose table. The index intentionally excludes the serialized session-row
`:revoke` hash and ORM `session.update!` calls. It does not list implicit Rails CSRF storage or
OmniAuth gem-internal `state` operations.

| Key expression                                                                 | Access | Location                                                                            | Source line                                                                                                             |
| ------------------------------------------------------------------------------ | ------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/check/email/otps_controller.rb:70` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/check/email/otps_controller.rb:113` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/check/email/otps_controller.rb:122` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:115` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:122` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/telephones_controller.rb:145` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/telephones_controller.rb:293` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/emails_controller.rb:169` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/auth/app/sign/up/emails_controller.rb:361` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/concerns/sign_up_sequence_controller_support.rb:480` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.dig(:app_sign_up_flow_locator, "nonce")` | read | `app/controllers/concerns/sign_up_sequence_controller_support.rb:511` | `session.dig(:app_sign_up_flow_locator, "nonce")` |
| `session.key?(OIDC_LOGOUT_REQUEST_SESSION_KEY)` | read | `app/controllers/concerns/sign_oidc_logout.rb:269` | `session.key?(OIDC_LOGOUT_REQUEST_SESSION_KEY)` |
| `session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY]`        | read   | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:184`            | `return if session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY].blank?`                                |
| `session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]`                       | read   | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:196`            | `ceremony: { state: session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] },`                                          |
| `session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]`                              | read   | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:225`            | `flow_id: session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY],`                                                             |
| `session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]`                       | read   | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:233`            | `candidate_present: session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY].present?,`                                   |
| `session[:auth_app_up_sequence_id]`                                            | write  | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:284`            | `session[:auth_app_up_sequence_id] = cycle.public_id`                                                                   |
| `session[SOCIAL_INTENT_SESSION_KEY]`                                           | read   | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:563`            | `explicit_intent = session[SOCIAL_INTENT_SESSION_KEY]`                                                                  |
| `session[:sign_in_email_cooldown_address]`                                     | read   | `app/controllers/auth/app/sign/in/emails_controller.rb:560`                         | `return false if session[:sign_in_email_cooldown_address] != normalized_address`                                        |
| `session[:sign_in_email_cooldown_at]`                                          | read   | `app/controllers/auth/app/sign/in/emails_controller.rb:562`                         | `last_sent_at = session[:sign_in_email_cooldown_at]`                                                                    |
| `session[:sign_in_email_cooldown_address]`                                     | write  | `app/controllers/auth/app/sign/in/emails_controller.rb:569`                         | `session[:sign_in_email_cooldown_address] = normalized_address`                                                         |
| `session[:sign_in_email_cooldown_at]`                                          | write  | `app/controllers/auth/app/sign/in/emails_controller.rb:570`                         | `session[:sign_in_email_cooldown_at] = Time.current.to_i`                                                               |
| `session[:user_telephone_registration]`                                        | read   | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:47`            | `registration = (session[:user_telephone_registration] \|\| {}).dup`                                                    |
| `session[:user_telephone_registration]`                                        | write  | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:50`            | `session[:user_telephone_registration] = registration`                                                                  |
| `session[:user_telephone_otp_last_sent_at]`                                    | write  | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:51`            | `session[:user_telephone_otp_last_sent_at] = Time.current.to_i`                                                         |
| `session[:user_telephone_registration]`                                        | read   | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:127`           | `registration = (session[:user_telephone_registration] \|\| {}).dup`                                                    |
| `session[:user_telephone_registration]`                                        | write  | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:130`           | `session[:user_telephone_registration] = registration`                                                                  |
| `session[:user_telephone_registration]`                                        | write  | `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb:172`           | `session[:user_telephone_registration] = nil`                                                                           |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb:69`         | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb:100`        | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb:113`        | `session[:inertia_clear_history] = true`                                                                                |
| `session[:auth_app_up_sequence_id]`                                            | write  | `app/controllers/auth/app/sign/up/emails_controller.rb:173`                         | `session[:auth_app_up_sequence_id] = flow.public_id`                                                                    |
| `session[:user_telephone_registration]`                                        | write  | `app/controllers/auth/app/sign/up/telephones_controller.rb:36`                      | `session[:user_telephone_registration] = nil`                                                                           |
| `session[:user_telephone_registration]`                                        | write  | `app/controllers/auth/app/sign/up/telephones_controller.rb:140`                     | `session[:user_telephone_registration] = result.session_payload`                                                        |
| `session[:auth_app_up_sequence_id]`                                            | write  | `app/controllers/auth/app/sign/up/telephones_controller.rb:149`                     | `session[:auth_app_up_sequence_id] = flow.public_id`                                                                    |
| `session[:user_telephone_registration]`                                        | write  | `app/controllers/auth/app/sign/up/telephones_controller.rb:150`                     | `session[:user_telephone_registration] = result.session_payload.merge(`                                                 |
| `session.delete(:user_telephone_registration)`                                 | delete | `app/controllers/auth/app/sign/up/telephones_controller.rb:159`                     | `session.delete(:user_telephone_registration)`                                                                          |
| `session[:user_telephone_registration]`                                        | read   | `app/controllers/auth/app/sign/up/telephones_controller.rb:316`                     | `def session_public_id_from_registration(registration_session = session[:user_telephone_registration])`                 |
| `session[:user_telephone_otp_last_sent_at]`                                    | read   | `app/controllers/auth/app/sign/up/telephones_controller.rb:322`                     | `last_sent_at = session[:user_telephone_otp_last_sent_at]`                                                              |
| `session[SocialAuth::SOCIAL_LINK_COMPLETION_SESSION_KEY]`                      | read   | `app/controllers/auth/app/social/link_completions_controller.rb:26`                 | `marker = session[SocialAuth::SOCIAL_LINK_COMPLETION_SESSION_KEY]`                                                      |
| `session.delete(SocialAuth::SOCIAL_LINK_COMPLETION_SESSION_KEY)`               | delete | `app/controllers/auth/app/social/link_completions_controller.rb:48`                 | `session.delete(SocialAuth::SOCIAL_LINK_COMPLETION_SESSION_KEY)`                                                        |
| `session.delete(::Auth::Org::Social::SessionsController::PT_SESSION_KEY)`      | delete | `app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb:149`            | `@consumed_pt = session.delete(::Auth::Org::Social::SessionsController::PT_SESSION_KEY) \`                              |
| `session[PT_SESSION_KEY]`                                                      | write  | `app/controllers/auth/org/social/sessions_controller.rb:100`                        | `session[PT_SESSION_KEY] = signed_pt_param if signed_pt_param.present?`                                                 |
| `session[:email_registration_transaction_ref]`                                 | write  | `app/controllers/base/app/identity/emails/registrations_controller.rb:67`           | `session[:email_registration_transaction_ref] = issued.transaction.transaction_id`                                      |
| `session[registration_session_key]`                                            | write  | `app/controllers/base/app/identity/telephones/registrations_controller.rb:68`       | `session[registration_session_key] = @user_telephone.id`                                                                |
| `session[registration_session_key]`                                            | read   | `app/controllers/base/app/identity/telephones/registrations_controller.rb:172`      | `def current_registration_telephone = ClientTelephone.find_by(id: session[registration_session_key])`                   |
| `session.delete(registration_transaction_session_key)`                         | delete | `app/controllers/base/app/identity/telephones/registrations_controller.rb:198`      | `session.delete(registration_transaction_session_key)`                                                                  |
| `session[registration_transaction_session_key]`                                | write  | `app/controllers/base/app/identity/telephones/registrations_controller.rb:203`      | `session[registration_transaction_session_key] = issued.transaction.transaction_id`                                     |
| `session[registration_transaction_session_key]`                                | read   | `app/controllers/base/app/identity/telephones/registrations_controller.rb:247`      | `reference = session[registration_transaction_session_key]`                                                             |
| `session.delete(registration_session_key)`                                     | delete | `app/controllers/base/app/identity/telephones/registrations_controller.rb:268`      | `session.delete(registration_session_key)`                                                                              |
| `session.delete(registration_transaction_session_key)`                         | delete | `app/controllers/base/app/identity/telephones/registrations_controller.rb:269`      | `session.delete(registration_transaction_session_key)`                                                                  |
| `session[:settings_telephone_registration_id]`                                 | write  | `app/controllers/base/app/identity/telephones_controller.rb:104`                    | `session[:settings_telephone_registration_id] = @user_telephone.id`                                                     |
| `session[:settings_telephone_registration_transaction_ref]`                    | write  | `app/controllers/base/app/identity/telephones_controller.rb:105`                    | `session[:settings_telephone_registration_transaction_ref] = issued.transaction.transaction_id`                         |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/base/app/roots_controller.rb:21`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/base/app/roots_controller.rb:30`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/base/app/secret_issuances_controller.rb:48`                        | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/base/app/secret_issuances_controller.rb:68`                        | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/base/app/secret_issuances_controller.rb:82`                        | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/base/app/secret_presentations_controller.rb:34`                    | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/base/app/secrets_controller.rb:92`                                 | `session[:inertia_clear_history] = true`                                                                                |
| `session[:client_secret_operation]`                                            | read   | `app/controllers/base/app/secrets_controller.rb:117`                                | `locator = session[:client_secret_operation]`                                                                           |
| `session[:client_secret_operation]`                                            | write  | `app/controllers/base/app/secrets_controller.rb:129`                                | `session[:client_secret_operation] = locator`                                                                           |
| `session[:client_secret_operation]`                                            | read   | `app/controllers/base/app/secrets_controller.rb:135`                                | `locator = session[:client_secret_operation]`                                                                           |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/base/com/roots_controller.rb:18`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[registration_session_key]`                                            | write  | `app/controllers/base/org/identity/emails/registrations_controller.rb:82`           | `session[registration_session_key] = @staff_email.public_id`                                                            |
| `session[:staff_email_registration_transaction_ref]`                           | write  | `app/controllers/base/org/identity/emails/registrations_controller.rb:128`          | `session[:staff_email_registration_transaction_ref] = issued.transaction.transaction_id`                                |
| `session[registration_session_key]`                                            | read   | `app/controllers/base/org/identity/emails/registrations_controller.rb:191`          | `current_operator.staff_emails.find_by(public_id: session[registration_session_key])`                                   |
| `session[:staff_email_registration_transaction_ref]`                           | read   | `app/controllers/base/org/identity/emails/registrations_controller.rb:202`          | `reference = session[:staff_email_registration_transaction_ref]`                                                        |
| `session.delete(registration_session_key)`                                     | delete | `app/controllers/base/org/identity/emails/registrations_controller.rb:213`          | `session.delete(registration_session_key)`                                                                              |
| `session.delete(:staff_email_registration_transaction_ref)`                    | delete | `app/controllers/base/org/identity/emails/registrations_controller.rb:214`          | `session.delete(:staff_email_registration_transaction_ref)`                                                             |
| `session[:staff_secret_credential_raw]`                                        | write  | `app/controllers/base/org/identity/secret_credentials_controller.rb:47`             | `session[:staff_secret_credential_raw] = @raw_secret_credential`                                                        |
| `session.delete(:staff_secret_credential_raw)`                                 | delete | `app/controllers/base/org/identity/secret_credentials_controller.rb:59`             | `raw_secret_credential = session.delete(:staff_secret_credential_raw)`                                                  |
| `session[:staff_secret_credential_raw]`                                        | write  | `app/controllers/base/org/identity/secret_credentials_controller.rb:81`             | `session[:staff_secret_credential_raw] = @raw_secret_credential`                                                        |
| `session[:staff_secret_credential_raw]`                                        | read   | `app/controllers/base/org/identity/secret_credentials_controller.rb:263`            | `@raw_secret_credential = session[:staff_secret_credential_raw].presence \|\|`                                          |
| `session[:staff_secret_credential_raw]`                                        | write  | `app/controllers/base/org/identity/secret_credentials_controller.rb:265`            | `session[:staff_secret_credential_raw] = @raw_secret_credential`                                                        |
| `session[registration_session_key]`                                            | write  | `app/controllers/base/org/identity/telephones/registrations_controller.rb:77`       | `session[registration_session_key] = @staff_telephone.id`                                                               |
| `session[registration_session_key]`                                            | read   | `app/controllers/base/org/identity/telephones/registrations_controller.rb:202`      | `current_operator.staff_telephones.find_by(id: session[registration_session_key])`                                      |
| `session[:settings_telephone_registration_transaction_ref]`                    | read   | `app/controllers/base/org/identity/telephones/registrations_controller.rb:213`      | `reference = session[:settings_telephone_registration_transaction_ref]`                                                 |
| `session.delete(registration_session_key)`                                     | delete | `app/controllers/base/org/identity/telephones/registrations_controller.rb:224`      | `session.delete(registration_session_key)`                                                                              |
| `session.delete(:settings_telephone_registration_transaction_ref)`             | delete | `app/controllers/base/org/identity/telephones/registrations_controller.rb:225`      | `session.delete(:settings_telephone_registration_transaction_ref)`                                                      |
| `session[:staff_telephone_registration_id]`                                    | write  | `app/controllers/base/org/identity/telephones_controller.rb:53`                     | `session[:staff_telephone_registration_id] = @staff_telephone.id`                                                       |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/base/org/roots_controller.rb:21`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/base/org/roots_controller.rb:30`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[session_key]`                                                         | read   | `app/controllers/concerns/authentication_base.rb:220`                               | `return nil if session[session_key].blank?`                                                                             |
| `session[session_key]`                                                         | read   | `app/controllers/concerns/authentication_base.rb:226`                               | `scope.find_by(id: session[session_key])`                                                                               |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/authentication_base.rb:364`                               | `session[:inertia_clear_history] = true if establishment == :root_login && result[:status] == :success`                 |
| `session[DEFAULT_PT_SESSION_KEY]`                                              | write  | `app/controllers/concerns/authentication_base.rb:937`                               | `session[DEFAULT_PT_SESSION_KEY] = token if token.present?`                                                             |
| `session[:pending_mfa]`                                                        | write  | `app/controllers/concerns/authentication_base.rb:2678`                              | `session[:pending_mfa] = {`                                                                                             |
| `session[:mfa_user_id]`                                                        | write  | `app/controllers/concerns/authentication_base.rb:2696`                              | `session[:mfa_user_id] = resource.id`                                                                                   |
| `session[:pending_mfa]`                                                        | read   | `app/controllers/concerns/authentication_base.rb:2700`                              | `raw = session[:pending_mfa]`                                                                                           |
| `session.delete(:pending_mfa)`                                                 | delete | `app/controllers/concerns/authentication_base.rb:2737`                              | `session.delete(:pending_mfa)`                                                                                          |
| `session.delete(:mfa_user_id)`                                                 | delete | `app/controllers/concerns/authentication_base.rb:2738`                              | `session.delete(:mfa_user_id)`                                                                                          |
| `session[AuthenticationBase::BULLETIN_SESSION_KEY]`                            | write  | `app/controllers/concerns/authentication_bulletin_gate.rb:11`                       | `session[AuthenticationBase::BULLETIN_SESSION_KEY] = {`                                                                 |
| `session[AuthenticationBase::BULLETIN_SESSION_KEY]`                            | read   | `app/controllers/concerns/authentication_bulletin_gate.rb:21`                       | `raw = session[AuthenticationBase::BULLETIN_SESSION_KEY]`                                                               |
| `session[AuthenticationBase::BULLETIN_SESSION_KEY]`                            | write  | `app/controllers/concerns/authentication_bulletin_gate.rb:45`                       | `session[AuthenticationBase::BULLETIN_SESSION_KEY] = data.merge(`                                                       |
| `session.delete(AuthenticationBase::BULLETIN_SESSION_KEY)`                     | delete | `app/controllers/concerns/authentication_bulletin_gate.rb:53`                       | `session.delete(AuthenticationBase::BULLETIN_SESSION_KEY)`                                                              |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/authentication_logoutable.rb:72`                          | `session[:inertia_clear_history] = true`                                                                                |
| `session[session_key]`                                                         | write  | `app/controllers/concerns/authentication_redirects.rb:26`                           | `session[session_key] = value`                                                                                          |
| `session[session_key]`                                                         | read   | `app/controllers/concerns/authentication_redirects.rb:36`                           | `pt_param = signed_pt_param.presence \|\| session[session_key]`                                                         |
| `session.delete(session_key)`                                                  | delete | `app/controllers/concerns/authentication_redirects.rb:37`                           | `session.delete(session_key)`                                                                                           |
| `session[session_key]`                                                         | read   | `app/controllers/concerns/authentication_redirects.rb:46`                           | `signed_pt_param.presence \|\| session[session_key]`                                                                    |
| `session[:authentication_pt_nonce]`                                            | read   | `app/controllers/concerns/authentication_redirects.rb:347`                          | `session_nonce = session[:authentication_pt_nonce].to_s`                                                                |
| `session[:authentication_pt_nonce]`                                            | write  | `app/controllers/concerns/authentication_redirects.rb:435`                          | `session[:authentication_pt_nonce] \|\|=`                                                                               |
| `session[:authentication_return_target_nonce]`                                 | read   | `app/controllers/concerns/authentication_redirects.rb:436`                          | `session[:authentication_return_target_nonce] \|\| SecureRandom.urlsafe_base64(24)`                                     |
| `session[:authentication_return_target_nonce]`                                 | write  | `app/controllers/concerns/authentication_redirects.rb:437`                          | `session[:authentication_return_target_nonce] \|\|= session[:authentication_pt_nonce]`                                  |
| `session[:authentication_pt_nonce]`                                            | read   | `app/controllers/concerns/authentication_redirects.rb:437`                          | `session[:authentication_return_target_nonce] \|\|= session[:authentication_pt_nonce]`                                  |
| `session[welcome_gate_key]`                                                    | write  | `app/controllers/concerns/authentication_sequence_gate.rb:291`                      | `session[welcome_gate_key] = {`                                                                                         |
| `session[SessionLimitGate::GATE_SESSION_KEY]`                                  | read   | `app/controllers/concerns/authentication_sequence_gate.rb:508`                      | `gate = session[SessionLimitGate::GATE_SESSION_KEY]`                                                                    |
| `session[BROWSER_NONCE_SESSION_KEY]`                                           | write  | `app/controllers/concerns/base_admission_browser_binding.rb:23`                     | `session[BROWSER_NONCE_SESSION_KEY] = Base64.urlsafe_encode64(`                                                         |
| `session[BROWSER_NONCE_SESSION_KEY]`                                           | read   | `app/controllers/concerns/base_admission_browser_binding.rb:42`                     | `value = session[BROWSER_NONCE_SESSION_KEY].to_s.presence`                                                              |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/base_settings_withdrawal_flow.rb:89`                      | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/base_sign_in_limitations.rb:129`                          | `session[:inertia_clear_history] = true`                                                                                |
| `session[SessionLimitGate::GATE_SESSION_KEY]`                                  | read   | `app/controllers/concerns/base_sign_in_limitations.rb:180`                          | `gate = session[SessionLimitGate::GATE_SESSION_KEY]`                                                                    |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/base_sign_in_limitations.rb:288`                          | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/base_sign_in_limitations.rb:314`                          | `session[:inertia_clear_history] = true`                                                                                |
| `session[SessionLimitGate::GATE_SESSION_KEY]`                                  | read   | `app/controllers/concerns/base_sign_in_limitations.rb:374`                          | `gate = session[SessionLimitGate::GATE_SESSION_KEY]`                                                                    |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/concerns/base_sign_out_destination.rb:47`                          | `clear_history: @sign_out_notice.present? \|\| session[:inertia_clear_history] == true`                                 |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/base_step_up_cancellation.rb:94`                          | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/base_step_up_completion.rb:59`                            | `session[:inertia_clear_history] = true`                                                                                |
| `session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY]`              | write  | `app/controllers/concerns/base_step_up_intent.rb:47`                                | `session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] = previous_browser_nonce if`                           |
| `session[:base_step_up_conflict]`                                              | write  | `app/controllers/concerns/base_step_up_intent.rb:80`                                | `session[:base_step_up_conflict] = {`                                                                                   |
| `session[:base_step_up_conflict]`                                              | read   | `app/controllers/concerns/base_step_up_intent.rb:120`                               | `state = session[:base_step_up_conflict]`                                                                               |
| `session.delete(:base_step_up_conflict)`                                       | delete | `app/controllers/concerns/base_step_up_intent.rb:137`                               | `session.delete(:base_step_up_conflict)`                                                                                |
| `session.delete(:base_step_up_conflict)`                                       | delete | `app/controllers/concerns/base_step_up_intent.rb:142`                               | `session.delete(:base_step_up_conflict)`                                                                                |
| `session.delete(:base_step_up_conflict)`                                       | delete | `app/controllers/concerns/base_step_up_intent.rb:179`                               | `session.delete(:base_step_up_conflict)`                                                                                |
| `session[:base_step_up_marker_locator]`                                        | read   | `app/controllers/concerns/base_step_up_transaction_marker.rb:53`                    | `value = session[:base_step_up_marker_locator]`                                                                         |
| `session[:base_step_up_marker_locator]`                                        | write  | `app/controllers/concerns/base_step_up_transaction_marker.rb:64`                    | `session[:base_step_up_marker_locator] = locator`                                                                       |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/browser_rp_authentication.rb:793`                         | `session[:inertia_clear_history] = true`                                                                                |
| `session[REENTRY_SESSION_KEY]`                                                 | write  | `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:51`                 | `session[REENTRY_SESSION_KEY] = { "email_public_id" => email.public_id,`                                                |
| `session[REENTRY_SESSION_KEY]`                                                 | write  | `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:59`                 | `session[REENTRY_SESSION_KEY] = { "email_public_id" => PublicId.generate,`                                              |
| `session.delete(REENTRY_SESSION_KEY)`                                          | delete | `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:94`                 | `session.delete(REENTRY_SESSION_KEY)`                                                                                   |
| `session[REENTRY_SESSION_KEY]`                                                 | read   | `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:133`                | `data = session[REENTRY_SESSION_KEY]`                                                                                   |
| `session.delete(REENTRY_SESSION_KEY)`                                          | delete | `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:137`                | `session.delete(REENTRY_SESSION_KEY)`                                                                                   |
| `session[REENTRY_SESSION_KEY]`                                                 | read   | `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:169`                | `state = session[REENTRY_SESSION_KEY]`                                                                                  |
| `session.delete(:oidc_code_verifier)`                                          | delete | `app/controllers/concerns/oidc_callback.rb:311`                                     | `session.delete(:oidc_code_verifier)`                                                                                   |
| `session.delete(:oidc_state)`                                                  | delete | `app/controllers/concerns/oidc_callback.rb:312`                                     | `session.delete(:oidc_state)`                                                                                           |
| `session.delete(:oidc_nonce)`                                                  | delete | `app/controllers/concerns/oidc_callback.rb:313`                                     | `session.delete(:oidc_nonce)`                                                                                           |
| `session.delete(:oidc_pt)`                                                     | delete | `app/controllers/concerns/oidc_callback.rb:314`                                     | `session.delete(:oidc_pt)`                                                                                              |
| `session.delete(:oidc_max_age)`                                                | delete | `app/controllers/concerns/oidc_callback.rb:315`                                     | `session.delete(:oidc_max_age)`                                                                                         |
| `session.delete(OIDC_PENDING_FLOWS_SESSION_KEY)`                               | delete | `app/controllers/concerns/oidc_callback.rb:316`                                     | `session.delete(OIDC_PENDING_FLOWS_SESSION_KEY) if pending_flows`                                                       |
| `session[OIDC_PENDING_FLOWS_SESSION_KEY]`                                      | read   | `app/controllers/concerns/oidc_callback.rb:322`                                     | `flows = session[OIDC_PENDING_FLOWS_SESSION_KEY]`                                                                       |
| `session.delete(OIDC_PENDING_FLOWS_SESSION_KEY)`                               | delete | `app/controllers/concerns/oidc_callback.rb:342`                                     | `session.delete(OIDC_PENDING_FLOWS_SESSION_KEY)`                                                                        |
| `session[OIDC_PENDING_FLOWS_SESSION_KEY]`                                      | write  | `app/controllers/concerns/oidc_callback.rb:344`                                     | `session[OIDC_PENDING_FLOWS_SESSION_KEY] = flows`                                                                       |
| `session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]`                          | read   | `app/controllers/concerns/oidc_rp_logout_launcher.rb:77`                            | `notice_id = session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]`                                                       |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/oidc_rp_logout_launcher.rb:99`                            | `session[:inertia_clear_history] = true`                                                                                |
| `session[OIDC_PENDING_FLOWS_SESSION_KEY]`                                      | write  | `app/controllers/concerns/oidc_sso_initiator.rb:129`                                | `session[OIDC_PENDING_FLOWS_SESSION_KEY] = { jti => flow }`                                                             |
| `session[SESSION_KEY]`                                                         | write  | `app/controllers/concerns/org_normal_sign_in_transaction.rb:39`                     | `session[SESSION_KEY] = {`                                                                                              |
| `session[SESSION_KEY]`                                                         | read   | `app/controllers/concerns/org_normal_sign_in_transaction.rb:54`                     | `raw = session[SESSION_KEY]`                                                                                            |
| `session.delete(SESSION_KEY)`                                                  | delete | `app/controllers/concerns/org_normal_sign_in_transaction.rb:85`                     | `session.delete(SESSION_KEY)`                                                                                           |
| `session[SESSION_KEY]`                                                         | write  | `app/controllers/concerns/org_normal_sign_in_transaction.rb:139`                    | `session[SESSION_KEY] = transaction.merge(`                                                                             |
| `session[:timezone]`                                                           | write  | `app/controllers/concerns/preference_core.rb:83`                                    | `session[:timezone] = timezone`                                                                                         |
| `session[:timezone]`                                                           | write  | `app/controllers/concerns/preference_core.rb:115`                                   | `session[:timezone] = timezone`                                                                                         |
| `session[:language]`                                                           | write  | `app/controllers/concerns/preference_core.rb:533`                                   | `session[:language] = option_id_to_language(@preference_language.option_id, preference_prefix)`                         |
| `session[:timezone]`                                                           | write  | `app/controllers/concerns/preference_global.rb:316`                                 | `session[:timezone] = timezone_value if !request.get? && !request.head?`                                                |
| `session[GATE_SESSION_KEY]`                                                    | write  | `app/controllers/concerns/session_limit_gate.rb:54`                                 | `session[GATE_SESSION_KEY] = {`                                                                                         |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/concerns/session_limit_gate.rb:66`                                 | `gate = session[GATE_SESSION_KEY]`                                                                                      |
| `session.delete(GATE_SESSION_KEY)`                                             | delete | `app/controllers/concerns/session_limit_gate.rb:69`                                 | `session.delete(GATE_SESSION_KEY)`                                                                                      |
| `session.delete(GATE_SESSION_KEY)`                                             | delete | `app/controllers/concerns/session_limit_gate.rb:78`                                 | `session.delete(GATE_SESSION_KEY)`                                                                                      |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/concerns/session_limit_gate.rb:82`                                 | `gate = session[GATE_SESSION_KEY]`                                                                                      |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/concerns/session_limit_gate.rb:89`                                 | `gate = session[GATE_SESSION_KEY]`                                                                                      |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/concerns/session_limit_gate.rb:96`                                 | `valid_gate?(session[GATE_SESSION_KEY])`                                                                                |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/concerns/session_limit_gate.rb:123`                                | `gate = session[GATE_SESSION_KEY]`                                                                                      |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/concerns/session_limit_gate.rb:134`                                | `gate = session[GATE_SESSION_KEY]`                                                                                      |
| `session[SESSION_KEY]`                                                         | read   | `app/controllers/concerns/sign_email_registrable.rb:49`                             | `current_state = session[SESSION_KEY]`                                                                                  |
| `session[SESSION_KEY]`                                                         | write  | `app/controllers/concerns/sign_email_registrable.rb:52`                             | `session[SESSION_KEY] = current_state`                                                                                  |
| `session[SESSION_KEY]`                                                         | write  | `app/controllers/concerns/sign_email_registrable.rb:57`                             | `session[SESSION_KEY] = next_state if next_state`                                                                       |
| `session[SESSION_KEY]`                                                         | write  | `app/controllers/concerns/sign_email_registrable.rb:61`                             | `session[SESSION_KEY] = STATE_INIT`                                                                                     |
| `session[registration_email_session_key]`                                      | write  | `app/controllers/concerns/sign_email_registration_flow.rb:57`                       | `session[registration_email_session_key] = @user_email.public_id`                                                       |
| `session[registration_email_session_key]`                                      | read   | `app/controllers/concerns/sign_email_registration_flow.rb:182`                      | `email_registration_target_user.client_emails.find_by(public_id: session[registration_email_session_key])`              |
| `session[:email_registration_transaction_ref]`                                 | read   | `app/controllers/concerns/sign_email_registration_flow.rb:193`                      | `reference = session[:email_registration_transaction_ref]`                                                              |
| `session.delete(registration_email_session_key)`                               | delete | `app/controllers/concerns/sign_email_registration_flow.rb:230`                      | `session.delete(registration_email_session_key)`                                                                        |
| `session.delete(:email_registration_transaction_ref)`                          | delete | `app/controllers/concerns/sign_email_registration_flow.rb:231`                      | `session.delete(:email_registration_transaction_ref)`                                                                   |
| `session.delete(SessionLimitGate::GATE_SESSION_KEY)`                           | delete | `app/controllers/concerns/sign_in_path_refusal.rb:62`                               | `session.delete(SessionLimitGate::GATE_SESSION_KEY)`                                                                    |
| `session.delete(:pending_mfa)`                                                 | delete | `app/controllers/concerns/sign_in_path_refusal.rb:63`                               | `session.delete(:pending_mfa)`                                                                                          |
| `session.delete(:mfa_user_id)`                                                 | delete | `app/controllers/concerns/sign_in_path_refusal.rb:64`                               | `session.delete(:mfa_user_id)`                                                                                          |
| `session.delete(:external_authentication_ceremony_reference)`                  | delete | `app/controllers/concerns/sign_in_path_refusal.rb:65`                               | `session.delete(:external_authentication_ceremony_reference)`                                                           |
| `session.delete(:sign_up_email_flow_state)`                                    | delete | `app/controllers/concerns/sign_in_path_refusal.rb:66`                               | `session.delete(:sign_up_email_flow_state)`                                                                             |
| `session.delete(:email_registration_transaction_ref)`                          | delete | `app/controllers/concerns/sign_in_path_refusal.rb:67`                               | `session.delete(:email_registration_transaction_ref)`                                                                   |
| `session.delete(welcome_gate_key)`                                             | delete | `app/controllers/concerns/sign_in_welcome_gate.rb:23`                               | `session.delete(welcome_gate_key)`                                                                                      |
| `session[welcome_gate_key]`                                                    | read   | `app/controllers/concerns/sign_in_welcome_gate.rb:27`                               | `gate = session[welcome_gate_key]`                                                                                      |
| `session[welcome_gate_key]`                                                    | write  | `app/controllers/concerns/sign_in_welcome_gate.rb:39`                               | `session[welcome_gate_key] = gate.merge("remaining" => remaining)`                                                      |
| `session[welcome_gate_key]`                                                    | read   | `app/controllers/concerns/sign_in_welcome_gate.rb:45`                               | `gate = session[welcome_gate_key]`                                                                                      |
| `session[OIDC_LOGOUT_COMPLETED_SESSION_KEY]`                                   | read   | `app/controllers/concerns/sign_oidc_logout.rb:35`                                   | `if session[OIDC_LOGOUT_COMPLETED_SESSION_KEY] == true && current_session_public_id.blank?`                             |
| `session[OIDC_LOGOUT_COMPLETED_SESSION_KEY]`                                   | write  | `app/controllers/concerns/sign_oidc_logout.rb:160`                                  | `session[OIDC_LOGOUT_COMPLETED_SESSION_KEY] = true`                                                                     |
| `session[OIDC_LOGOUT_REQUEST_SESSION_KEY]`                                     | read   | `app/controllers/concerns/sign_oidc_logout.rb:279`                                  | `payload = session[OIDC_LOGOUT_REQUEST_SESSION_KEY]`                                                                    |
| `session.delete(OIDC_LOGOUT_COMPLETED_SESSION_KEY)`                            | delete | `app/controllers/concerns/sign_oidc_logout.rb:289`                                  | `session.delete(OIDC_LOGOUT_COMPLETED_SESSION_KEY)`                                                                     |
| `session[OIDC_LOGOUT_REQUEST_SESSION_KEY]`                                     | write  | `app/controllers/concerns/sign_oidc_logout.rb:290`                                  | `session[OIDC_LOGOUT_REQUEST_SESSION_KEY] = oidc_logout_request_payload(result, device: device, grant: grant)`          |
| `session[:settings_telephone_registration_transaction_ref]`                    | write  | `app/controllers/concerns/sign_operator_telephone_registrable.rb:53`                | `session[:settings_telephone_registration_transaction_ref] = issued.transaction.transaction_id`                         |
| `session.delete(SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY)`              | delete | `app/controllers/concerns/sign_out_cancellation.rb:15`                              | `session.delete(SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY)`                                                       |
| `session.delete(SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY)`                   | delete | `app/controllers/concerns/sign_out_cancellation.rb:16`                              | `session.delete(SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY)`                                                            |
| `session[SIGN_OUT_NOTICE_SESSION_KEY]`                                         | write  | `app/controllers/concerns/sign_out_notice.rb:35`                                    | `session[SIGN_OUT_NOTICE_SESSION_KEY] = notice_id`                                                                      |
| `session[SIGN_OUT_NOTICE_SESSION_KEY]`                                         | read   | `app/controllers/concerns/sign_out_notice.rb:40`                                    | `notice_id = session[SIGN_OUT_NOTICE_SESSION_KEY]`                                                                      |
| `session.delete(SIGN_OUT_NOTICE_SESSION_KEY)`                                  | delete | `app/controllers/concerns/sign_out_notice.rb:41`                                    | `session.delete(SIGN_OUT_NOTICE_SESSION_KEY)`                                                                           |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/sign_out_notice.rb:105`                                   | `session[:inertia_clear_history] = true`                                                                                |
| `session.delete(secret_credential_ceremony_session_key)`                       | delete | `app/controllers/concerns/sign_settings_secret_credential_registration.rb:49`       | `session.delete(secret_credential_ceremony_session_key)`                                                                |
| `session.delete(:totp_enrollment)`                                             | delete | `app/controllers/concerns/sign_settings_totp_registration.rb:9`                     | `session.delete(:totp_enrollment)`                                                                                      |
| `session.delete(:totp_ceremony)`                                               | delete | `app/controllers/concerns/sign_settings_totp_registration.rb:10`                    | `session.delete(:totp_ceremony)`                                                                                        |
| `session.delete(:private_key)`                                                 | delete | `app/controllers/concerns/sign_settings_totp_registration.rb:11`                    | `session.delete(:private_key)`                                                                                          |
| `session[:sign_up_flow_id]`                                                    | read   | `app/controllers/concerns/sign_signup_observability.rb:17`                          | `flow_id: session[:sign_up_flow_id] \|\|`                                                                               |
| `session[:app_sign_up_flow_locator]`                                           | read   | `app/controllers/concerns/sign_signup_observability.rb:18`                          | `(session[:app_sign_up_flow_locator].is_a?(Hash) && session[:app_sign_up_flow_locator]["public_id"]),`                  |
| `session[:app_sign_up_flow_locator]`                                           | read   | `app/controllers/concerns/sign_signup_observability.rb:18`                          | `(session[:app_sign_up_flow_locator].is_a?(Hash) && session[:app_sign_up_flow_locator]["public_id"]),`                  |
| `session[sign_up_sequence_session_key]`                                        | read   | `app/controllers/concerns/sign_up_sequence_controller_support.rb:300`               | `session[sign_up_sequence_session_key].presence`                                                                        |
| `session[sign_up_telephone_registration_session_key]`                          | read   | `app/controllers/concerns/sign_up_sequence_controller_support.rb:388`               | `registration = session[sign_up_telephone_registration_session_key] \|\| {}`                                            |
| `session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]`                       | read   | `app/controllers/concerns/social_auth.rb:68`                                        | `session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]`                                                                |
| `session.delete(:social_auth_nonce)`                                           | delete | `app/controllers/concerns/social_auth.rb:79`                                        | `session.delete(:social_auth_nonce)`                                                                                    |
| `session[SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY]`                    | write  | `app/controllers/concerns/social_auth.rb:85`                                        | `session[SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY] = admission_ceremony_session_id.to_s`                        |
| `session.delete(SOCIAL_INTENT_SESSION_KEY)`                                    | delete | `app/controllers/concerns/social_auth.rb:86`                                        | `session.delete(SOCIAL_INTENT_SESSION_KEY)`                                                                             |
| `session.delete(SOCIAL_STARTED_AT_SESSION_KEY)`                                | delete | `app/controllers/concerns/social_auth.rb:87`                                        | `session.delete(SOCIAL_STARTED_AT_SESSION_KEY)`                                                                         |
| `session.delete(SOCIAL_FLOW_ID_SESSION_KEY)`                                   | delete | `app/controllers/concerns/social_auth.rb:88`                                        | `session.delete(SOCIAL_FLOW_ID_SESSION_KEY)`                                                                            |
| `session.delete(SOCIAL_PROVIDER_SESSION_KEY)`                                  | delete | `app/controllers/concerns/social_auth.rb:89`                                        | `session.delete(SOCIAL_PROVIDER_SESSION_KEY)`                                                                           |
| `session.delete(SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY)`             | delete | `app/controllers/concerns/social_auth.rb:91`                                        | `session.delete(SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY)`                                                      |
| `session[SOCIAL_INTENT_SESSION_KEY]`                                           | write  | `app/controllers/concerns/social_auth.rb:92`                                        | `session[SOCIAL_INTENT_SESSION_KEY] = intent`                                                                           |
| `session[SOCIAL_STARTED_AT_SESSION_KEY]`                                       | write  | `app/controllers/concerns/social_auth.rb:93`                                        | `session[SOCIAL_STARTED_AT_SESSION_KEY] = Time.current.to_i`                                                            |
| `session[SOCIAL_FLOW_ID_SESSION_KEY]`                                          | write  | `app/controllers/concerns/social_auth.rb:94`                                        | `session[SOCIAL_FLOW_ID_SESSION_KEY] = PublicId.generate`                                                               |
| `session[SOCIAL_PROVIDER_SESSION_KEY]`                                         | write  | `app/controllers/concerns/social_auth.rb:95`                                        | `session[SOCIAL_PROVIDER_SESSION_KEY] = provider`                                                                       |
| `session[:social_auth_nonce]`                                                  | write  | `app/controllers/concerns/social_auth.rb:97`                                        | `session[:social_auth_nonce] = SecureRandom.urlsafe_base64(32) if provider.to_s == "apple"`                             |
| `session[SOCIAL_ENTRY_SESSION_KEY]`                                            | write  | `app/controllers/concerns/social_auth.rb:98`                                        | `session[SOCIAL_ENTRY_SESSION_KEY] = entry if entry.present?`                                                           |
| `session[SOCIAL_RI_SESSION_KEY]`                                               | write  | `app/controllers/concerns/social_auth.rb:99`                                        | `session[SOCIAL_RI_SESSION_KEY] = ri if ri.present?`                                                                    |
| `session.delete(SOCIAL_PT_SESSION_KEY)`                                        | delete | `app/controllers/concerns/social_auth.rb:100`                                       | `session.delete(SOCIAL_PT_SESSION_KEY)`                                                                                 |
| `session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]`                       | read   | `app/controllers/concerns/social_auth.rb:104`                                       | `previous_state = session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]`                                               |
| `session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]`              | read   | `app/controllers/concerns/social_auth.rb:105`                                       | `previous_provider = session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]`                                   |
| `session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]`                       | write  | `app/controllers/concerns/social_auth.rb:111`                                       | `session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = state`                                                        |
| `session[SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY]`            | write  | `app/controllers/concerns/social_auth.rb:112`                                       | `session[SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i`                                 |
| `session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)`        | delete | `app/controllers/concerns/social_auth.rb:113`                                       | `session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)`                                                 |
| `session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]`              | write  | `app/controllers/concerns/social_auth.rb:114`                                       | `session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider`                                            |
| `session[SOCIAL_INTENT_SESSION_KEY]`                                           | read   | `app/controllers/concerns/social_auth.rb:118`                                       | `intent: session[SOCIAL_INTENT_SESSION_KEY],`                                                                           |
| `session[SOCIAL_USER_ID_SESSION_KEY]`                                          | write  | `app/controllers/concerns/social_auth.rb:124`                                       | `session[SOCIAL_USER_ID_SESSION_KEY] = current_resource&.id`                                                            |
| `session.delete(SOCIAL_USER_ID_SESSION_KEY)`                                   | delete | `app/controllers/concerns/social_auth.rb:126`                                       | `session.delete(SOCIAL_USER_ID_SESSION_KEY)`                                                                            |
| `session[SOCIAL_FLOW_ID_SESSION_KEY]`                                          | read   | `app/controllers/concerns/social_auth.rb:147`                                       | `return if intent == "link" && session[SOCIAL_FLOW_ID_SESSION_KEY].present?`                                            |
| `session[SOCIAL_INTENT_SESSION_KEY]`                                           | read   | `app/controllers/concerns/social_auth.rb:158`                                       | `session[SOCIAL_INTENT_SESSION_KEY] \|\| "login"`                                                                       |
| `session[SOCIAL_ENTRY_SESSION_KEY]`                                            | read   | `app/controllers/concerns/social_auth.rb:162`                                       | `session[SOCIAL_ENTRY_SESSION_KEY].presence`                                                                            |
| `session[SOCIAL_RI_SESSION_KEY]`                                               | read   | `app/controllers/concerns/social_auth.rb:166`                                       | `session[SOCIAL_RI_SESSION_KEY].presence`                                                                               |
| `session.delete(SOCIAL_INTENT_SESSION_KEY)`                                    | delete | `app/controllers/concerns/social_auth.rb:170`                                       | `session.delete(SOCIAL_INTENT_SESSION_KEY)`                                                                             |
| `session.delete(SOCIAL_USER_ID_SESSION_KEY)`                                   | delete | `app/controllers/concerns/social_auth.rb:171`                                       | `session.delete(SOCIAL_USER_ID_SESSION_KEY)`                                                                            |
| `session.delete(SOCIAL_STARTED_AT_SESSION_KEY)`                                | delete | `app/controllers/concerns/social_auth.rb:172`                                       | `session.delete(SOCIAL_STARTED_AT_SESSION_KEY)`                                                                         |
| `session.delete(SOCIAL_FLOW_ID_SESSION_KEY)`                                   | delete | `app/controllers/concerns/social_auth.rb:173`                                       | `session.delete(SOCIAL_FLOW_ID_SESSION_KEY)`                                                                            |
| `session.delete(SOCIAL_PROVIDER_SESSION_KEY)`                                  | delete | `app/controllers/concerns/social_auth.rb:174`                                       | `session.delete(SOCIAL_PROVIDER_SESSION_KEY)`                                                                           |
| `session.delete(SOCIAL_PT_SESSION_KEY)`                                        | delete | `app/controllers/concerns/social_auth.rb:175`                                       | `session.delete(SOCIAL_PT_SESSION_KEY)`                                                                                 |
| `session.delete(SOCIAL_ENTRY_SESSION_KEY)`                                     | delete | `app/controllers/concerns/social_auth.rb:176`                                       | `session.delete(SOCIAL_ENTRY_SESSION_KEY)`                                                                              |
| `session.delete(SOCIAL_RI_SESSION_KEY)`                                        | delete | `app/controllers/concerns/social_auth.rb:177`                                       | `session.delete(SOCIAL_RI_SESSION_KEY)`                                                                                 |
| `session.delete(SOCIAL_CEREMONY_GRANT_SESSION_KEY)`                            | delete | `app/controllers/concerns/social_auth.rb:178`                                       | `session.delete(SOCIAL_CEREMONY_GRANT_SESSION_KEY)`                                                                     |
| `session.delete(SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY)`             | delete | `app/controllers/concerns/social_auth.rb:179`                                       | `session.delete(SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY)`                                                      |
| `session.delete(:social_auth_nonce)`                                           | delete | `app/controllers/concerns/social_auth.rb:180`                                       | `session.delete(:social_auth_nonce)`                                                                                    |
| `session.delete(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)`                | delete | `app/controllers/concerns/social_auth.rb:181`                                       | `session.delete(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)`                                                         |
| `session.delete(SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY)`     | delete | `app/controllers/concerns/social_auth.rb:182`                                       | `session.delete(SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY)`                                              |
| `session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)`        | delete | `app/controllers/concerns/social_auth.rb:183`                                       | `session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)`                                                 |
| `session.delete(SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY)`       | delete | `app/controllers/concerns/social_auth.rb:184`                                       | `session.delete(SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY)`                                                |
| `session[SOCIAL_FLOW_ID_SESSION_KEY]`                                          | read   | `app/controllers/concerns/social_auth.rb:269`                                       | `flow_id = session[SOCIAL_FLOW_ID_SESSION_KEY]`                                                                         |
| `session[SOCIAL_USER_ID_SESSION_KEY]`                                          | read   | `app/controllers/concerns/social_auth.rb:317`                                       | `user_id = session[SOCIAL_USER_ID_SESSION_KEY].presence`                                                                |
| `session[SOCIAL_CEREMONY_GRANT_SESSION_KEY]`                                   | write  | `app/controllers/concerns/social_auth.rb:350`                                       | `session[SOCIAL_CEREMONY_GRANT_SESSION_KEY] = grant["transaction_id"].to_s`                                             |
| `session[SOCIAL_CEREMONY_GRANT_SESSION_KEY]`                                   | read   | `app/controllers/concerns/social_auth.rb:356`                                       | `raw_value = session[SOCIAL_CEREMONY_GRANT_SESSION_KEY].presence`                                                       |
| `session[SOCIAL_STARTED_AT_SESSION_KEY]`                                       | read   | `app/controllers/concerns/social_auth.rb:553`                                       | `started_at = session[SOCIAL_STARTED_AT_SESSION_KEY]`                                                                   |
| `session[SOCIAL_FLOW_ID_SESSION_KEY]`                                          | read   | `app/controllers/concerns/social_auth.rb:564`                                       | `flow_id: session[SOCIAL_FLOW_ID_SESSION_KEY],`                                                                         |
| `session[SOCIAL_USER_ID_SESSION_KEY]`                                          | read   | `app/controllers/concerns/social_auth.rb:574`                                       | `intent_user_id = session[SOCIAL_USER_ID_SESSION_KEY].to_s`                                                             |
| `session[SOCIAL_PROVIDER_SESSION_KEY]`                                         | read   | `app/controllers/concerns/social_auth.rb:601`                                       | `provider = provider.presence \|\| session[SOCIAL_PROVIDER_SESSION_KEY] \|\| params[:provider] \|\| provider_from_path` |
| `session[SOCIAL_LINK_COMPLETION_SESSION_KEY]`                                  | write  | `app/controllers/concerns/social_auth.rb:703`                                       | `session[SOCIAL_LINK_COMPLETION_SESSION_KEY] = [candidate.ref, token.public_id]`                                        |
| `session[SOCIAL_FLOW_ID_SESSION_KEY]`                                          | read   | `app/controllers/concerns/social_auth.rb:777`                                       | `flow_id: session[SOCIAL_FLOW_ID_SESSION_KEY],`                                                                         |
| `request.session["omniauth.state"]`                                            | read   | `app/controllers/concerns/social_callback_guard.rb:77`                              | `state = request.session["omniauth.state"].to_s.presence \|\| request.params["state"].to_s.presence`                    |
| `request.session[SOCIAL_STATE_SESSION_KEY]`                                    | read   | `app/controllers/concerns/social_callback_guard.rb:79`                              | `return if request.session[SOCIAL_STATE_SESSION_KEY].to_s == state &&`                                                  |
| `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY]`                           | read   | `app/controllers/concerns/social_callback_guard.rb:80`                              | `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY].to_s == provider`                                                   |
| `request.session[SOCIAL_STATE_SESSION_KEY]`                                    | write  | `app/controllers/concerns/social_callback_guard.rb:82`                              | `request.session[SOCIAL_STATE_SESSION_KEY] = state`                                                                     |
| `request.session[SOCIAL_STATE_STARTED_AT_SESSION_KEY]`                         | write  | `app/controllers/concerns/social_callback_guard.rb:83`                              | `request.session[SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i`                                              |
| `request.session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                     | delete | `app/controllers/concerns/social_callback_guard.rb:84`                              | `request.session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                                                              |
| `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY]`                           | write  | `app/controllers/concerns/social_callback_guard.rb:85`                              | `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider`                                                         |
| `request.session["omniauth.nonce"]`                                            | read   | `app/controllers/concerns/social_callback_guard.rb:95`                              | `strategy_has_value: request.session["omniauth.nonce"].present?,`                                                       |
| `session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY]`        | read   | `app/controllers/concerns/social_callback_guard.rb:246`                             | `expected_session_id = session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY]`                           |
| `session[SOCIAL_STATE_SESSION_KEY]`                                            | read   | `app/controllers/concerns/social_callback_guard.rb:255`                             | `expected: session[SOCIAL_STATE_SESSION_KEY].to_s.presence \|\|`                                                        |
| `session[SOCIAL_STATE_STARTED_AT_SESSION_KEY]`                                 | read   | `app/controllers/concerns/social_callback_guard.rb:257`                             | `started_at: session[SOCIAL_STATE_STARTED_AT_SESSION_KEY].to_i,`                                                        |
| `session[SOCIAL_STATE_USED_AT_SESSION_KEY]`                                    | read   | `app/controllers/concerns/social_callback_guard.rb:258`                             | `used_at: session[SOCIAL_STATE_USED_AT_SESSION_KEY],`                                                                   |
| `session[SOCIAL_STATE_PROVIDER_SESSION_KEY]`                                   | read   | `app/controllers/concerns/social_callback_guard.rb:259`                             | `stored_provider: session[SOCIAL_STATE_PROVIDER_SESSION_KEY].to_s.presence,`                                            |
| `session[SOCIAL_STATE_SESSION_KEY]`                                            | write  | `app/controllers/concerns/social_callback_guard.rb:281`                             | `session[SOCIAL_STATE_SESSION_KEY] = expected_state`                                                                    |
| `session[SOCIAL_STATE_PROVIDER_SESSION_KEY]`                                   | write  | `app/controllers/concerns/social_callback_guard.rb:282`                             | `session[SOCIAL_STATE_PROVIDER_SESSION_KEY] \|\|= provider`                                                             |
| `session[SOCIAL_STATE_STARTED_AT_SESSION_KEY]`                                 | write  | `app/controllers/concerns/social_callback_guard.rb:283`                             | `session[SOCIAL_STATE_STARTED_AT_SESSION_KEY] =`                                                                        |
| `session[SOCIAL_STATE_STARTED_AT_SESSION_KEY]`                                 | read   | `app/controllers/concerns/social_callback_guard.rb:284`                             | `Time.current.to_i if session[SOCIAL_STATE_STARTED_AT_SESSION_KEY].blank?`                                              |
| `session[SOCIAL_STATE_USED_AT_SESSION_KEY]`                                    | write  | `app/controllers/concerns/social_callback_guard.rb:285`                             | `session[SOCIAL_STATE_USED_AT_SESSION_KEY] = Time.current.to_i`                                                         |
| `session.delete(SOCIAL_STATE_SESSION_KEY)`                                     | delete | `app/controllers/concerns/social_callback_guard.rb:289`                             | `session.delete(SOCIAL_STATE_SESSION_KEY)`                                                                              |
| `session.delete(SOCIAL_STATE_STARTED_AT_SESSION_KEY)`                          | delete | `app/controllers/concerns/social_callback_guard.rb:290`                             | `session.delete(SOCIAL_STATE_STARTED_AT_SESSION_KEY)`                                                                   |
| `session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                             | delete | `app/controllers/concerns/social_callback_guard.rb:291`                             | `session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                                                                      |
| `session.delete(SOCIAL_STATE_PROVIDER_SESSION_KEY)`                            | delete | `app/controllers/concerns/social_callback_guard.rb:292`                             | `session.delete(SOCIAL_STATE_PROVIDER_SESSION_KEY)`                                                                     |
| `session.delete(SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY)` | delete | `app/controllers/concerns/social_callback_guard.rb:293`                             | `session.delete(SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY)`                                          |
| `request.session[SOCIAL_STATE_SESSION_KEY]`                                    | write  | `app/controllers/concerns/social_callback_guard.rb:420`                             | `request.session[SOCIAL_STATE_SESSION_KEY] = query["state"].to_s`                                                       |
| `request.session[SOCIAL_STATE_STARTED_AT_SESSION_KEY]`                         | write  | `app/controllers/concerns/social_callback_guard.rb:421`                             | `request.session[SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i`                                              |
| `request.session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                     | delete | `app/controllers/concerns/social_callback_guard.rb:422`                             | `request.session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                                                              |
| `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY]`                           | write  | `app/controllers/concerns/social_callback_guard.rb:423`                             | `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider`                                                         |
| `request.session[SOCIAL_STATE_SESSION_KEY]`                                    | write  | `app/controllers/concerns/social_callback_guard.rb:435`                             | `request.session[SOCIAL_STATE_SESSION_KEY] = generated_state`                                                           |
| `request.session[SOCIAL_STATE_STARTED_AT_SESSION_KEY]`                         | write  | `app/controllers/concerns/social_callback_guard.rb:436`                             | `request.session[SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i`                                              |
| `request.session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                     | delete | `app/controllers/concerns/social_callback_guard.rb:437`                             | `request.session.delete(SOCIAL_STATE_USED_AT_SESSION_KEY)`                                                              |
| `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY]`                           | write  | `app/controllers/concerns/social_callback_guard.rb:438`                             | `request.session[SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider`                                                         |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/concerns/surface_chrome.rb:44`                                     | `inertia_share clear_history: -> { session[:inertia_clear_history] == true }`                                           |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/concerns/withdrawal_ceremony_authentication.rb:58`                 | `session[:inertia_clear_history] = true`                                                                                |
| `session[REENTRY_SESSION_KEY]`                                                 | write  | `app/controllers/concerns/withdrawal_ceremony_reentry.rb:47`                        | `session[REENTRY_SESSION_KEY] = {`                                                                                      |
| `session[REENTRY_SESSION_KEY]`                                                 | write  | `app/controllers/concerns/withdrawal_ceremony_reentry.rb:57`                        | `session[REENTRY_SESSION_KEY] = {`                                                                                      |
| `session.delete(REENTRY_SESSION_KEY)`                                          | delete | `app/controllers/concerns/withdrawal_ceremony_reentry.rb:99`                        | `session.delete(REENTRY_SESSION_KEY)`                                                                                   |
| `session[REENTRY_SESSION_KEY]`                                                 | read   | `app/controllers/concerns/withdrawal_ceremony_reentry.rb:137`                       | `data = session[REENTRY_SESSION_KEY]`                                                                                   |
| `session.delete(REENTRY_SESSION_KEY)`                                          | delete | `app/controllers/concerns/withdrawal_ceremony_reentry.rb:141`                       | `session.delete(REENTRY_SESSION_KEY)`                                                                                   |
| `session[REENTRY_SESSION_KEY]`                                                 | read   | `app/controllers/concerns/withdrawal_ceremony_reentry.rb:161`                       | `state = session[REENTRY_SESSION_KEY]`                                                                                  |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/visa/app/sign/in/limitations_controller.rb:155`                    | `session[:inertia_clear_history] = true`                                                                                |
| `session[GATE_SESSION_KEY]`                                                    | read   | `app/controllers/visa/app/sign/in/limitations_controller.rb:215`                    | `gate = session[GATE_SESSION_KEY]`                                                                                      |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/visa/app/sign/in/limitations_controller.rb:313`                    | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/visa/app/sign/in/limitations_controller.rb:347`                    | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/warp/app/roots_controller.rb:19`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/warp/app/sign/outs_controller.rb:47`                               | `session[:inertia_clear_history] = true`                                                                                |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/warp/com/roots_controller.rb:18`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[:inertia_clear_history]`                                              | read   | `app/controllers/warp/org/roots_controller.rb:19`                                   | `clear_history: session[:inertia_clear_history] == true`                                                                |
| `session[:inertia_clear_history]`                                              | write  | `app/controllers/warp/org/sign/outs_controller.rb:47`                               | `session[:inertia_clear_history] = true`                                                                                |
| `session[SESSION_KEY]`                                                         | read   | `app/services/sign_app_in_email_authentication_state.rb:26`                         | `raw = session[SESSION_KEY]`                                                                                            |
| `session[SESSION_KEY]`                                                         | write  | `app/services/sign_app_in_email_authentication_state.rb:33`                         | `session[SESSION_KEY] = { "id" => email.id, "address" => nil }`                                                         |
| `session[SESSION_KEY]`                                                         | write  | `app/services/sign_app_in_email_authentication_state.rb:37`                         | `session[SESSION_KEY] = { "id" => nil, "address" => address.to_s }`                                                     |
| `session.delete(SESSION_KEY)`                                                  | delete | `app/services/sign_app_in_email_authentication_state.rb:41`                         | `session.delete(SESSION_KEY)`                                                                                           |
| `session.delete(session_key)`                                                  | delete | `app/services/sign_in_cycle_locator.rb:64`                                          | `session.delete(session_key)`                                                                                           |
| `session[session_key]`                                                         | read   | `app/services/sign_in_cycle_locator.rb:72`                                          | `payload = session[session_key]`                                                                                        |
| `session[session_key]`                                                         | write  | `app/services/sign_in_cycle_locator.rb:79`                                          | `session[session_key] = {`                                                                                              |
| `@session[key_for(surface)]`                                                   | write  | `app/services/sign_in_sequence_carrier.rb:47`                                       | `@session[key_for(surface)] = payload`                                                                                  |
| `@session.delete(KEY)`                                                         | delete | `app/services/sign_in_sequence_carrier.rb:48`                                       | `@session.delete(KEY) unless key_for(surface) == KEY`                                                                   |
| `@session[key_for(sequence.surface)]`                                          | write  | `app/services/sign_in_sequence_carrier.rb:65`                                       | `@session[key_for(sequence.surface)] = payload`                                                                         |
| `@session.delete(key_for(surface)`                                             | delete | `app/services/sign_in_sequence_carrier.rb:83`                                       | `@session.delete(key_for(surface)) if surface`                                                                          |
| `@session.delete(KEY)`                                                         | delete | `app/services/sign_in_sequence_carrier.rb:84`                                       | `@session.delete(KEY)`                                                                                                  |
| `@session[key_for(sequence.surface)]`                                          | write  | `app/services/sign_in_sequence_carrier.rb:100`                                      | `@session[key_for(sequence.surface)] = payload`                                                                         |
| `@session[surface_key]`                                                        | read   | `app/services/sign_in_sequence_carrier.rb:108`                                      | `payload = @session[surface_key] if surface_key.present?`                                                               |
| `@session[KEY]`                                                                | read   | `app/services/sign_in_sequence_carrier.rb:113`                                      | `payload = @session[KEY]`                                                                                               |
| `@session[key_for(payload["surface"]`                                          | read   | `app/services/sign_in_sequence_carrier.rb:118`                                      | `@session[key_for(payload["surface"])] = payload`                                                                       |
| `@session.delete(KEY)`                                                         | delete | `app/services/sign_in_sequence_carrier.rb:119`                                      | `@session.delete(KEY)`                                                                                                  |
| `session[session_key]`                                                         | write  | `app/services/sign_up_cycle_locator.rb:118`                                         | `session[session_key] = {`                                                                                              |
| `session.delete(session_key)`                                                  | delete | `app/services/sign_up_cycle_locator.rb:126`                                         | `session.delete(session_key)`                                                                                           |
| `session[session_key]`                                                         | read   | `app/services/sign_up_cycle_locator.rb:164`                                         | `payload = session[session_key]`                                                                                        |
| `@session[@keys.fetch(:cycle_locator)]`                                        | read   | `app/services/sign_up_session_state.rb:43`                                          | `@session[@keys.fetch(:cycle_locator)]`                                                                                 |
| `@session.delete(@keys.fetch(:cycle_locator)`                                  | delete | `app/services/sign_up_session_state.rb:48`                                          | `@session.delete(@keys.fetch(:cycle_locator))`                                                                          |
| `@session[@keys.fetch(:cycle_locator)]`                                        | write  | `app/services/sign_up_session_state.rb:50`                                          | `@session[@keys.fetch(:cycle_locator)] = value`                                                                         |
| `@session[@keys.fetch(:sequence_id)]`                                          | read   | `app/services/sign_up_session_state.rb:55`                                          | `@session[@keys.fetch(:sequence_id)]`                                                                                   |
| `@session.delete(@keys.fetch(:sequence_id)`                                    | delete | `app/services/sign_up_session_state.rb:60`                                          | `@session.delete(@keys.fetch(:sequence_id))`                                                                            |
| `@session[@keys.fetch(:sequence_id)]`                                          | write  | `app/services/sign_up_session_state.rb:62`                                          | `@session[@keys.fetch(:sequence_id)] = value`                                                                           |
| `@session[@keys.fetch(:telephone_otp)]`                                        | read   | `app/services/sign_up_session_state.rb:67`                                          | `@session[@keys.fetch(:telephone_otp)] \|\| {}`                                                                         |
| `@session.delete(@keys.fetch(:telephone_otp)`                                  | delete | `app/services/sign_up_session_state.rb:72`                                          | `@session.delete(@keys.fetch(:telephone_otp))`                                                                          |
| `@session[@keys.fetch(:telephone_otp)]`                                        | write  | `app/services/sign_up_session_state.rb:74`                                          | `@session[@keys.fetch(:telephone_otp)] = value`                                                                         |
| `@session[@keys.fetch(:existing_email)]`                                       | read   | `app/services/sign_up_session_state.rb:79`                                          | `@session[@keys.fetch(:existing_email)]`                                                                                |
| `@session.delete(@keys.fetch(:existing_email)`                                 | delete | `app/services/sign_up_session_state.rb:84`                                          | `@session.delete(@keys.fetch(:existing_email))`                                                                         |
| `@session[@keys.fetch(:existing_email)]`                                       | write  | `app/services/sign_up_session_state.rb:86`                                          | `@session[@keys.fetch(:existing_email)] = value`                                                                        |
| `@session[@keys.fetch(:existing_email_skip_otp)]`                              | read   | `app/services/sign_up_session_state.rb:91`                                          | `@session[@keys.fetch(:existing_email_skip_otp)] == true`                                                               |
| `@session.delete(@keys.fetch(:existing_email_skip_otp)`                        | delete | `app/services/sign_up_session_state.rb:96`                                          | `@session.delete(@keys.fetch(:existing_email_skip_otp))`                                                                |
| `@session[@keys.fetch(:existing_email_skip_otp)]`                              | write  | `app/services/sign_up_session_state.rb:98`                                          | `@session[@keys.fetch(:existing_email_skip_otp)] = true`                                                                |
| `@session.delete(@keys.fetch(:existing_email)`                                 | delete | `app/services/sign_up_session_state.rb:103`                                         | `@session.delete(@keys.fetch(:existing_email))`                                                                         |
| `@session.delete(@keys.fetch(:existing_email_skip_otp)`                        | delete | `app/services/sign_up_session_state.rb:104`                                         | `@session.delete(@keys.fetch(:existing_email_skip_otp))`                                                                |
| `@session.delete(@keys.fetch(:telephone_otp)`                                  | delete | `app/services/sign_up_session_state.rb:108`                                         | `@session.delete(@keys.fetch(:telephone_otp))`                                                                          |
| `@session.delete(k)`                                                           | delete | `app/services/sign_up_session_state.rb:112`                                         | `@keys.each_value { \|k\| @session.delete(k) }`                                                                         |
| `session[SESSION_KEY]`                                                         | read   | `app/services/webauthn/challenge_store.rb:143`                                      | `value = session[SESSION_KEY]`                                                                                          |
| `session[SESSION_KEY]`                                                         | write  | `app/services/webauthn/challenge_store.rb:148`                                      | `session[SESSION_KEY] = entries`                                                                                        |
| `session["omniauth.nonce"]`                                                    | write  | `lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb:21` | `session["omniauth.nonce"] = nonce`                                                                                     |
| `session.delete("omniauth.nonce")`                                             | delete | `lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb:59` | `nonce = session.delete("omniauth.nonce")`                                                                              |
| `session.delete("omniauth.pkce.verifier")`                                     | delete | `lib/omniauth/strategies/umaxica_entra.rb:105`                                      | `verifier = session.delete("omniauth.pkce.verifier")`                                                                   |

## Rails session reset sites

These locations currently clear some or all Rails session state. Under D-8, each host's sign-out or
flow-ending path must also clear every purpose cookie owned by that host; a Rails `reset_session`
alone will not clear independent cookies.

| Current reset site | Current use |
|---|---|
| `app/controllers/concerns/sign_entry_exit.rb:95` | Entry/exit lifecycle reset. |
| `app/controllers/concerns/auth_ceremony_context.rb:220` | Auth ceremony boundary reset. |
| `app/controllers/auth/app/settings/totps/enrollments_controller.rb:48` | TOTP enrollment reset. |
| `app/controllers/concerns/authentication_logoutable.rb:71` | Sign-out helper; called by its current-session/logout paths. |
| `app/controllers/concerns/oidc_rp_logout_launcher.rb:106` | RP-initiated sign-out reset helper. |

## Rails session exceptions and non-session findings

- _csrf_token (Rails authenticity token): remains in the Rails session as required for CSRF
  protection.
- omniauth.state: remains in Rails session per O-1 and OmniAuth's contract. It must still be checked
  against the corresponding social-purpose server transaction. omniauth.nonce and
  omniauth.pkce.verifier are not exceptions.
- inertia_clear_history: remains in Rails session per O-2; missing means false. Its presence is a
  navigation instruction, not authentication authority.
- session[:revoke] in base/app/identity/sessions_controller.rb and
  base/org/identity/sessions_controller.rb is a key in a serialized session-row hash, not the Rails
  browser session.
- Preference timezone and language values are Rails-session entries and are inventoried above;
  already-purpose-specific Preference cookies are outside this redesign's scope.

## O-3 cookie count and size estimate

The first count estimates newly migrated flow-purpose cookies, including separate social sign-in/link
and email/telephone registration purposes. The subtotal adds one Rails session
cookie per host, which remains for `_csrf_token`, `omniauth.state` and `inertia_clear_history`. Both
counts exclude existing purpose-specific authentication, preference, verification and device-session
cookies; those are outside this redesign and must be added when measuring the final browser total.
Ranges reflect callers shared through concerns and unresolved producers above; these are planning
estimates, not measurements of a deployed request header.

| Host | New flow-purpose cookies | Subtotal incl. Rails session cookie | Largest new flow cookie | Basis / unresolved check |
|---|---:|---:|---:|---|
| Auth APP | 12–16 | 13–17 | 1.5 KB | Sign-in, sign-up, social, OIDC, session-limit, MFA/checkpoint, contact and WebAuthn. |
| Auth ORG | 9–13 | 10–14 | 1.5 KB | Sign-in, Entra continuation, social/OIDC state, session-limit/checkpoint and WebAuthn. |
| Visa APP | 6–9 | 7–10 | 1.0 KB | Sign-in/session-limit, OIDC authorization/logout, return target and completion notice. |
| Visa ORG | 6–9 | 7–10 | 1.0 KB | Same purpose families as Visa APP with ORG-specific flow rows. |
| Base APP | 8–12 | 9–13 | 1.5 KB | Admission, step-up, contact registration, Secret issuance, OIDC and sign-out presentation. |
| Base ORG | 8–12 | 9–13 | 1.5 KB | Admission, step-up, contact registration, secret ceremony, OIDC and sign-out presentation. |
| Base COM | 1–3 | 2–4 | 1.0 KB | Locale/timezone, plus any shared return/notice caller found at implementation time. |
| Warp APP | 2–5 | 3–6 | 1.0 KB | OIDC continuation, return/notice and shared sign-in/session-limit callers. |
| Warp COM | 1–4 | 2–5 | 1.0 KB | Locale/timezone and shared continuation/notice callers. |
| Warp ORG | 2–5 | 3–6 | 1.0 KB | OIDC continuation, return/notice and shared sign-in/session-limit callers. |
| Core APP | 3–6 | 4–7 | 1.0 KB | OIDC, sign-in/session-limit, return target and notice callers. |
| Core ORG | 3–6 | 4–7 | 1.0 KB | ORG equivalents; confirm actual OIDC host inclusion. |
| Palm APP | 3–6 | 4–7 | 1.0 KB | OIDC, sign-in/session-limit, return target and notice callers. |
| Tech ORG | 3–6 | 4–7 | 1.0 KB | OIDC and shared sign-in/session-limit/return callers. |
| Edit ORG | 3–6 | 4–7 | 1.0 KB | OIDC and shared sign-in/session-limit/return callers. |

Design target: each encrypted purpose cookie stays below 1,536 bytes; typical locator-only cookies
should be below 800 bytes. The new per-purpose JSON should carry only a flow_id, a server record
reference, timestamps and (where required) a nonce digest. The current passkey_challenges session map and
raw contact/secret values must first move into server-side records; serializing them directly would
invalidate this estimate and conflict with D-2. A host at the top of its range would send roughly 23
KB of cookie value plus names/attributes at the 1.5 KB ceiling. Reverse-proxy and application
request-header limits still need to be checked against this total before release.

## Inventory gaps to resolve before implementation

1. Confirm whether any out-of-tree component writes sign_up_flow_id,
   external_authentication_ceremony_reference, the legacy OIDC keys or legacy TOTP keys.
2. Decide which persisted flow row owns the sequence currently stored only in SignInSequenceCarrier;
   it cannot satisfy O-3b as a cookie-only sequence.
3. Add/identify server-side ownership for org_normal_sign_in_transaction, WebAuthn challenge
   entries, raw ORG secret credential retry state and the dummy email sign-in address before their
   values move out of Rails session.
4. Confirm all included surfaces for shared concerns, especially Core ORG and the Warp/COM locale,
   session-limit and OIDC paths, before replacing the estimated host counts with measured counts.
5. Record the exact checkpoint transition for each sign-in method and each sign-up/contact/social
   flow from the current transition inventory. The cookie must never own the O-3c winner decision.

## Proposed migration order and acceptance-test mapping

The order follows the accepted Work order. “Write tests” means tests are authored against existing
behavior first and incident reproductions are confirmed failing before the migration in Work
order 2.

| Stage                   | Purpose families                                                                                                                                               | Acceptance criteria to cover                                  |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 1. Sign-in              | Sign-in cycle locator, sign-in sequence, email/MFA state, return target, session-limit gate, welcome/checkpoint                                                | AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-11, AC-12  |
| 2. Sign-up              | Sign-up locator/sequence, email and telephone state, OTP timing references                                                                                     | AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-11, AC-12 |
| 3. Social               | App social intent/state, Apple nonce, Entra continuation, social link and callback markers; preserve OmniAuth state exception                                  | AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12 |
| 4. OIDC                 | Pending authorization, PKCE/nonce server record, logout request and completion                                                                                 | AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-11, AC-12       |
| 5. Contact registration | APP/ORG email and telephone registration transaction refs, safe return target                                                                                  | AC-3, AC-4, AC-5, AC-6, AC-7, AC-10, AC-11, AC-12             |
| 6. Step-up              | Admission browser binding, transaction marker, conflict continuation                                                                                           | AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-11, AC-12       |
| 7. Other state          | Re-entry, WebAuthn challenge storage, bulletin/welcome/sign-out notice, secret issuance, locale/timezone; remove confirmed dead keys and add D-10 static guard | AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-11, AC-12             |

Every stage also repeats the relevant boundary assertions: no secret/contact/OTP in cookie data
(AC-10), wrong-host isolation (AC-6), wrong-purpose/tampered-key refusal (AC-5), expiry (AC-4), and
new-flow replacement/replay (AC-11/AC-12). AC-13 applies to every stage that can show restart
guidance; each migrated refusal path must provide the fixed surface Base `/sign` link and preserve
the refused GET/HEAD state.
