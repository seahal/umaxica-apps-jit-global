# Browser Flow State Inventory

Date: 2026-11-06

Status: Work order 1 inventory. This document records current behavior and proposed target shapes;
it does not authorize or describe an implementation. The accepted contract is
specs/browser-flow-state-cookies/spec.md.

## Scope and method

The source scan covered Ruby files under app/ and lib/, including direct session[...] access,
request.session[...], @session[...], dynamic-key accessors, session.delete, and Rails session reset
paths. Constants and their callers were followed to identify concrete keys and surfaces. Several
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
| `app_sign_in_flow_locator`                        | Credential sign-in locator                  |
| `org_sign_in_flow_locator`                        | Credential sign-in locator                  |
| `sign_in_sequence`                                | Post-authentication sequence/checkpoint     |
| `app_sign_in_sequence`                            | Post-authentication sequence/checkpoint     |
| `com_sign_in_sequence`                            | Post-authentication sequence/checkpoint     |
| `org_sign_in_sequence`                            | Post-authentication sequence/checkpoint     |
| `sign_in_checkpoint`                              | One-shot sign-in bulletin/checkpoint        |
| `app_sign_up_flow_locator`                        | APP sign-up locator                         |
| `auth_app_up_sequence_id`                         | APP sign-up navigation/observability        |
| `sign_up_flow_id`                                 | APP sign-up navigation/observability        |
| `sign_up_email_flow_state`                        | APP email sign-up state                     |
| `user_telephone_registration`                     | APP sign-up contact and OTP state           |
| `user_telephone_otp_last_sent_at`                 | APP sign-up contact and OTP state           |
| `sign_up_existing_email_id`                       | APP sign-up contact and OTP state           |
| `sign_up_existing_email_skip_otp`                 | APP sign-up contact and OTP state           |
| `sign_up_sequence_session_key`                    | Dynamic APP sign-up accessors               |
| `sign_up_telephone_registration_session_key`      | Dynamic APP sign-up accessors               |
| `sign_app_in_email_authentication`                | APP email sign-in authentication state      |
| `sign_in_email_cooldown_address`                  | APP email sign-in send cooldown             |
| `sign_in_email_cooldown_at`                       | APP email sign-in send cooldown             |
| `user_email_authentication_pt`                    | Generic return target                       |
| `authentication_pt_nonce`                         | Return-target browser binding               |
| `authentication_return_target_nonce`              | Return-target browser binding               |
| `pending_mfa`                                     | MFA continuation                            |
| `mfa_user_id`                                     | MFA continuation                            |
| `external_authentication_ceremony_reference`      | External ceremony cleanup key               |
| `session_limit_gate`                              | Session-limit resolution gate               |
| `app_sign_in_welcome`                             | One-shot welcome gate                       |
| `com_sign_in_welcome`                             | One-shot welcome gate                       |
| `org_sign_in_welcome`                             | One-shot welcome gate                       |
| `sign_in_welcome`                                 | One-shot welcome gate                       |
| `social_auth_intent`                              | Social login/link and callback state        |
| `social_auth_user_id`                             | Social login/link and callback state        |
| `social_auth_started_at`                          | Social login/link and callback state        |
| `social_auth_flow_id`                             | Social login/link and callback state        |
| `social_auth_provider`                            | Social login/link and callback state        |
| `social_auth_pt`                                  | Social login/link and callback state        |
| `social_auth_entry`                               | Social login/link and callback state        |
| `social_auth_ri`                                  | Social login/link and callback state        |
| `social_admission_ceremony_session_id`            | Social login/link and callback state        |
| `social_ceremony_grant`                           | Social login/link and callback state        |
| `social_link_completion`                          | Social login/link and callback state        |
| `social_auth_nonce`                               | Social login/link and callback state        |
| `social_auth_state`                               | Social login/link and callback state        |
| `social_auth_state_started_at`                    | Social login/link and callback state        |
| `social_auth_state_used_at`                       | Social login/link and callback state        |
| `social_auth_state_provider`                      | Social login/link and callback state        |
| `omniauth.state`                                  | OmniAuth state exception                    |
| `omniauth.nonce`                                  | Provider nonce and PKCE verifier            |
| `omniauth.pkce.verifier`                          | Provider nonce and PKCE verifier            |
| `auth_org_entra_omniauth_pt`                      | ORG Entra return target                     |
| `oidc_pending_flows`                              | OIDC pending authorization                  |
| `oidc_code_verifier`                              | Legacy OIDC cleanup keys                    |
| `oidc_state`                                      | Legacy OIDC cleanup keys                    |
| `oidc_nonce`                                      | Legacy OIDC cleanup keys                    |
| `oidc_pt`                                         | Legacy OIDC cleanup keys                    |
| `oidc_max_age`                                    | Legacy OIDC cleanup keys                    |
| `oidc_logout_request`                             | OIDC logout                                 |
| `oidc_logout_completed`                           | OIDC logout                                 |
| `email_registration_public_id`                    | Base APP email registration                 |
| `email_registration_transaction_ref`              | Base APP email registration                 |
| `email_registration_pt`                           | Base APP email registration                 |
| `settings_telephone_registration_id`              | Base APP telephone registration             |
| `settings_telephone_registration_transaction_ref` | Base APP telephone registration             |
| `staff_email_registration_public_id`              | Base ORG email registration                 |
| `staff_email_registration_transaction_ref`        | Base ORG email registration                 |
| `staff_telephone_registration_id`                 | Base ORG telephone registration             |
| `registration_session_key`                        | Dynamic Base contact-registration accessors |
| `registration_transaction_session_key`            | Dynamic Base contact-registration accessors |
| `base_step_up_marker_locator`                     | Base step-up                                |
| `base_step_up_conflict`                           | Base step-up                                |
| `auth_admission_browser_nonce`                    | Admission browser binding                   |
| `enforcement_recovery_reentry`                    | Recovery/withdrawal re-entry                |
| `withdrawal_ceremony_reentry`                     | Recovery/withdrawal re-entry                |
| `passkey_challenges`                              | WebAuthn challenges                         |
| `org_normal_sign_in_transaction`                  | ORG normal sign-in continuation             |
| `sign_out_notice`                                 | Sign-out notice                             |
| `client_secret_operation`                         | APP Secret issuance operation               |
| `staff_secret_credential_raw`                     | ORG Secret credential retry                 |
| `secret_credential_ceremony`                      | Legacy credential/TOTP cleanup              |
| `totp_enrollment`                                 | Legacy credential/TOTP cleanup              |
| `totp_ceremony`                                   | Legacy credential/TOTP cleanup              |
| `private_key`                                     | Legacy credential/TOTP cleanup              |
| `timezone`                                        | Preference session cache                    |
| `language`                                        | Preference session cache                    |
| `inertia_clear_history`                           | Inertia history-clear exception             |
| `_csrf_token`                                     | Rails CSRF exception                        |
| `load_session_record(session_key)`                | Unresolved generic dynamic accessor         |

## Keys and target contracts

| Current key(s); owner/source of writes and reads (exact access sites are in the index below) |
Flow and host/surface | Current server record and lifetime | Current lifetime and absent, expired,
or malformed behavior | Intended lifetime after migration | Proposed purpose cookie and JSON shape |
O-3b flow ID record; O-3c lock and checkpoint | |---|---|---|---|---|---| |
app_sign_in_flow_locator, org_sign_in_flow_locator; SignInCycleLocator | Credential sign-in;
Auth/Visa APP and ORG callers, with a host-local session at each caller | ClientSignInFlow or
OperatorSignInFlow; the row has its own expiry and terminal state | Rails cookie 14 days; DB expiry
is checked. Missing, unknown, terminal, nonce mismatch, or binding mismatch yields no current cycle
or the existing phase refusal. Malformed hash/required fields are treated as no current cycle
(KeyError is rescued). | __Host-umaxica-sign-in;
{"flow_id":"<public_id>","binding":"<opaque nonce>","surface":"app|org"}. The nonce remains a
binding value, not an authority. | Use the sign-in flow's random public ID as flow_id and retain the
nonce digest on the flow row. Lock that row in the named transition writer at the first committed
transition beyond entry/primary-pending; the exact transition must follow the sign-in transition
inventory for each method. | | sign_in_sequence, app_sign_in_sequence, com_sign_in_sequence,
org_sign_in_sequence; SignInSequenceCarrier | Post-authentication sequence/checkpoint; Auth/Visa and
any surface using the concern (APP/COM/ORG) | No corresponding server row was found for the sequence
payload. It contains its own generated ID, actor ID, step and references; 15-minute logical
expiry. | Rails cookie 14 days; sequence reader checks the embedded 15-minute expiry. Missing
payload is blank; malformed/expired values are rejected by sequence gates. Legacy generic key is
copied to a surface key and deleted when read. | Proposed server sequence row: 15 minutes or the
shorter parent sign-in-flow expiry; must be recorded explicitly. | Fold into the sign-in purpose
cookie only if the authoritative sign-in flow row represents these steps; otherwise
__Host-umaxica-sign-in-sequence;
{"flow_id":"<server flow id>","sequence_ref":"<server sequence ref>"}. Do not put actor IDs, return
paths, state, or mutable references in the cookie. | Current local sequence ID is not in a server
record. Replace/associate it with ClientSignInFlow or OperatorSignInFlow before claiming O-3b. Lock
the sign-in row on the first transition past entry. | | sign_in_checkpoint
(AuthenticationBase::BULLETIN_SESSION_KEY / AuthIoKeys::Session::CHECKPOINT) | One-shot sign-in
bulletin/checkpoint; Auth/Visa APP and ORG | Bulletin itself is a Client/Operator-owned record;
timeout is 2 hours. | Rails cookie 14 days; application checks issued_at against 2 hours and clears
malformed/expired state when consumed. Missing or unknown bulletin produces no bulletin. | Bulletin
expires after 2 hours; cookie expires at the bulletin record expiry. |
__Host-umaxica-sign-in-bulletin;
{"flow_id":"<sign-in flow id>","bulletin_ref":"<record id>","issued_at":123}. | Flow ID on the
sign-in flow row. Lock the sign-in flow and bulletin read-state transition on first checkpoint
completion; determine whether bulletin is the checkpoint or merely presentation from the transition
inventory. | | app_sign_up_flow_locator; SignUpCycleLocator | APP sign-up; Auth APP |
ClientSignUpFlow, bound to ClientAuthAdmissionBinding and Auth ceremony; flow has a configured TTL
and cleanup lifecycle. | Rails cookie 14 days; flow expiry is checked from the database. Missing
locator can start a new admitted flow; malformed/foreign ownership raises/refuses; a terminal
unreleased attempt remains blocked until cleanup completes. | Exactly ClientSignUpFlow.expires_at;
cookie expires no later than the flow row. | __Host-umaxica-sign-up;
{"flow_id":"<ClientSignUpFlow.public_id>","binding":"<opaque nonce>"}. | Use the sign-up flow public
ID already present on the row. Lock the admission binding/flow row while the first transition
commits beyond STARTED (the accepted sign-up transition writer decides the exact step). | |
auth_app_up_sequence_id, sign_up_flow_id (observability fallback); SignUpSessionState, sign-up
controllers and logging concern | APP sign-up navigation/observability; Auth APP | ClientSignUpFlow
when the value is produced by sign-up; sign_up_flow_id has no writer in app/ or lib/ found in this
scan. | Rails cookie 14 days. Missing sequence ID is treated as no sequence; stale or malformed ID
fails flow admission/lookup. Observability fallback can be absent. | Sign-up flow expiry; the
fallback key has no target lifetime until an active producer is confirmed. | Same
__Host-umaxica-sign-up; {"flow_id":"<ClientSignUpFlow.public_id>"}. Remove the duplicate sequence-ID
copy once the server row is the source. | ClientSignUpFlow.public_id; lock same sign-up transition
as above. Confirm external writers for sign_up_flow_id before removal. | |
sign_up_email_flow_state | APP email sign-up state (init, email_created, email_verified); Auth APP |
No server state record is linked to this enum-like browser value; underlying email verification has
a pending ClientEmail/OTP lifecycle. | Rails cookie 14 days; missing/invalid value is normalized to
init, then persisted. Illegal action/state redirects to the new sign-up email page. | Exactly the
parent ClientSignUpFlow expiry. | Same sign-up purpose cookie, with state held server-side; cookie
contains only flow_id and server reference. | Link to ClientSignUpFlow; lock its transition writer
when email creation/verification advances the flow. | | user_telephone_registration,
user_telephone_otp_last_sent_at, sign_up_existing_email_id, sign_up_existing_email_skip_otp;
SignUpSessionState and APP sign-up controllers | APP telephone/email sign-up; Auth APP | Telephone
proof and pending contact are held by sign-up/OTP records; existing_email_id refers to a
ClientEmail. The skip flag has no independent row. | Rails cookie 14 days. Telephone payload is
consumed by OTP/checkpoint controllers; missing payload makes the step unavailable/restart. OTP send
time is only an app-side cooldown timestamp. Invalid or expired OTP is rejected by the OTP writer.
Existing-email state is cleared on restart. | Telephone/OTP transaction expiry; cooldown timestamp
only through EmailOtpPolicy::SEND_COOLDOWN; existing-email fields through the parent sign-up flow
expiry. | Same sign-up purpose cookie;
{"flow_id":"<ClientSignUpFlow.public_id>","contact_transaction_ref":"<transaction id>"}. Do not copy
phone/email values, OTP data, or a boolean skip decision into the cookie. | Flow ID on
ClientSignUpFlow; lock the sign-up flow/admission record at contact issue and verification
transitions, with OTP attempt/verification remaining authoritative on its own transaction. | |
Dynamic sign_up_sequence_session_key, sign_up_telephone_registration_session_key; currently resolve
to auth_app_up_sequence_id and user_telephone_registration on APP | APP sign-up; Auth APP | Same
ClientSignUpFlow/pending contact records above | Same Rails and flow lifetimes above; supported only
for APP by current method bodies. An unsupported surface returns no key or fails the caller's
explicit surface handling. | Inherit the concrete sign-up flow or OTP record expiry referenced by
the resolved key. | Same sign-up cookie; dynamic key names disappear after migration. | Same sign-up
flow ID and lock as above. | | sign_app_in_email_authentication | APP email sign-in; Auth APP |
Existing path references a ClientEmail; dummy path stores submitted address and is used for timing
behavior. No independent record is linked by the current state object; the Auth ceremony stores
email OTP context when an OTP exists. | Rails cookie 14 days; missing state cannot continue the OTP
step. Malformed values are passed through as ID/address fields and later fail normal
lookup/verification. Dummy address may remain after an abandoned attempt. | Exactly the Auth email
OTP/ceremony expiry; abandoned attempts expire with that record. | __Host-umaxica-sign-in-email;
{"flow_id":"<sign-in flow id>","ceremony_ref":"<Auth ceremony ref>"}. Submitted contact address must
remain in its authoritative server-side ceremony/OTP attempt. | Flow ID on ClientSignInFlow plus
Auth ceremony binding; lock the sign-in flow/ceremony on successful evidence transition. | |
sign_in_email_cooldown_address, sign_in_email_cooldown_at | APP email sign-in send cooldown; Auth
APP | Email OTP policy/attempt records are authoritative for OTP issuance; no row currently owns
this session cooldown pair. | Rails cookie 14 days; code compares normalized email and a timestamp
with the short EmailOtpPolicy::SEND_COOLDOWN. Missing timestamp/address means cooldown is inactive;
malformed time becomes inactive by integer conversion. The address is contact data. | Only the
configured email send cooldown; delete/ignore once it expires. | Same sign-in-email purpose cookie;
keep only flow_id and an opaque cooldown/attempt reference. Store address and cooldown authority in
a server record. | ClientSignInFlow or the email OTP attempt should carry flow ID. Lock actor/email
OTP attempt at issuance; do not use the cookie as a cooldown lock. | | user_email_authentication_pt
(DEFAULT_PT_SESSION_KEY); generic preserve_pt/retrieve_pt | Return target through sign-in and
failure flows; Auth/Visa/Base/other includers | No general server record; signed pt may be supplied
from the request; otherwise this stores an encoded/signed target. | Rails cookie 14 days; consumed
reads delete it; malformed target is rejected/sanitized by signed-target validation. Missing target
falls back to caller default. | Parent sign-in/admission flow expiry; one-shot return reference is
consumed earlier. | __Host-umaxica-return-target;
{"flow_id":"<current flow id>","return_ref":"<server-side safe target ref>"}. Persist only a
server-validated same-host/path target, not encoded bearer material. | Parent flow row is the
flow-ID owner. No additional checkpoint lock; bind the return reference to the flow under its
initial issue transaction. | | authentication_pt_nonce, authentication_return_target_nonce | Signed
return-target/browser-binding nonce; shared authentication redirect concern on surfaces | No
separate row found; nonce is generated in the browser session and bound into signed PT processing. |
Rails cookie 14 days; missing value causes a new nonce; malformed/incorrect value fails signed
target verification and falls back/refuses. | Parent flow/admission expiry; one-shot binding is
consumed with the first accepted continuation. | Fold into the purpose-specific return-target
cookie; {"flow_id":"<parent flow id>","binding":"<random nonce>"}. Server record should persist a
digest/binding, not the raw nonce. | Store the ID and nonce digest with the parent admission/flow
record. Lock that record when accepting the first bound continuation. | | pending_mfa, mfa_user_id |
MFA continuation; Auth APP/ORG and shared authentication concern | Actor's MFA credential/status
rows and current sign-in flow; no dedicated browser-session MFA row is referenced here. | Rails
cookie 14 days; pending object supplies the second-factor context. Missing/malformed actor or MFA
data is refused by the continuation; cleanup deletes both values on refusal/completion. | MFA
challenge expiry, no longer than the parent sign-in flow. | __Host-umaxica-mfa;
{"flow_id":"<sign-in flow id>","challenge_ref":"<server-side MFA challenge ref>"}. No actor ID or
MFA payload in the cookie. | Flow ID on the sign-in flow/challenge record. Lock challenge/flow while
consuming a successful MFA response; first successful transition wins. | |
external_authentication_ceremony_reference (constant and refusal cleanup only) | External provider
ceremony cleanup; shared Auth sign-in path | No writer/reader in app/ or lib/ found; no linked
record established from this key in the current source scan. | If present, refusal deletes it; its
effective current expiry is Rails 14 days. It appears to be legacy cleanup state. | No target
lifetime while no active producer exists; if confirmed, equal the provider ceremony expiry. | No
cookie until an active producer/consumer is identified. If still required, use the owning provider
ceremony cookie with a server ceremony reference. | No flow ID or checkpoint can be assigned from
current source; confirm whether external producers exist before implementation/removal. | |
session_limit_gate | Session-limit resolution continuation; Auth/Visa APP/ORG |
ClientSignInFlow/OperatorSignInFlow plus SessionLimitResolutionTransaction child transaction; gate
itself carries nonce, safe PT, flow, challenge and binding. | Rails cookie 14 days; gate embeds a
15-minute TTL and is deleted on invalid/consumed paths. Missing, expired, malformed or bad nonce
redirects to login/refuses. | SessionLimitResolutionTransaction expiry (current gate TTL is 15
minutes), capped by parent sign-in-flow expiry. | __Host-umaxica-session-limit;
{"flow_id":"<sign-in flow public id>","resolution_ref":"<SessionLimitResolutionTransaction ref>","binding":"<opaque nonce>"}. |
Flow ID on sign-in flow and child transaction. Lock the resolution transaction and parent sign-in
flow when the selected-session resolution commits; the resolution writer is the checkpoint. | |
app_sign_in_welcome, com_sign_in_welcome, org_sign_in_welcome, fallback sign_in_welcome | One-shot
welcome page gate; Auth/Visa APP/COM/ORG callers | Sign-in flow row when sequence_id is populated;
no separate server row for the gate itself. | Rails cookie 14 days; gate embeds expires_at, a
remaining-use count and optional sequence ID. Expired, malformed, exhausted or mismatched gate is
cleared and returns false; absence skips the welcome page. | One-shot server welcome gate expiry;
use the shortest lifetime that allows the next welcome transition. | Fold into
__Host-umaxica-sign-in if its flow owns the welcome transition; otherwise __Host-umaxica-welcome;
{"flow_id":"<sign-in flow id>","welcome_ref":"<server-side one-shot gate ref>"}. | Flow ID on
sign-in flow. Lock the flow row when the welcome/checkpoint is consumed; one-shot gate consumption
must be atomic. | | Social group: social_auth_intent, social_auth_user_id, social_auth_started_at,
social_auth_flow_id, social_auth_provider, social_auth_pt, social_auth_entry, social_auth_ri,
social_admission_ceremony_session_id, social_ceremony_grant, social_link_completion,
social_auth_nonce; plus social_auth_state, social_auth_state_started_at, social_auth_state_used_at,
social_auth_state_provider | Social login/link/step-up and APP callback; Auth APP and Auth ORG Entra
entry where concern applies | SocialAuthCallbackStateStore has a short-lived state record; APP also
has ClientSocialCeremonyTransaction, ClientVisaSocialLinkAdmission, Auth ceremony and OIDC
grant/admission records. ORG sign-in uses Operator/Entra identity and Auth ceremony. Some
intent/entry/PT/RI values have no separate record today. | Rails cookie 14 days; social state is
intended to live 5 minutes and step-up flow 10 minutes. State store consumes/rejects mismatches.
Missing ceremony grant or admission ref prevents callback commit. social_auth_nonce is an Apple
nonce. Corrupt/old state commonly becomes callback refusal/csrf_detected; abandon paths can leave
other keys behind. | Per linked social transaction. Current state is 5 minutes and step-up/admission
records may be 10 minutes; each purpose cookie must match its own record expiry. |
__Host-umaxica-social;
{"flow_id":"<server social flow id>","ceremony_ref":"<Auth ceremony ref>","state_ref":"<SocialAuthCallbackStateStore ref>","provider":"<allowlisted provider>"}.
Keep PT/entry/RI in the parent server transaction; never place provider tokens, nonce secrets,
subject/contact data or actor IDs in JSON. | Social flow ID currently exists in the cookie session
but must be written to ClientSocialCeremonyTransaction/the corresponding ORG ceremony record. Lock
the social transaction/state record for the first callback commit that records authenticated
evidence or links the identity. | | omniauth.state, written/read by OmniAuth; omniauth.nonce,
written by lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb and
consumed by callback guard; omniauth.pkce.verifier, written by Entra strategy and deleted in
lib/omniauth/strategies/umaxica_entra.rb | OAuth social/OIDC provider round trips; Auth APP
Google/Apple and Auth ORG Entra | Social/OIDC authorization attempt and provider state;
omniauth.state is maintained by the gem. No app-owned PKCE verifier row was identified. | Rails
cookie 14 days. Gem state comparison fails callback on absent/mismatch; nonce/verifier are
one-attempt values but can persist if a flow is abandoned. | Exception: keep the Rails session
lifecycle. Move nonce/verifier to their provider-attempt server-record expiry (nonce/state window or
provider transaction expiry). | Only omniauth.state remains in Rails session by O-1. Move nonce and
verifier into __Host-umaxica-social/provider-purpose record, with
{"flow_id":"<social transaction id>","provider_state_ref":"<server ref>"}. Do not store
verifier/nonce plaintext in the cookie under D-2. | Server social/OIDC transaction owns flow ID,
nonce digest and PKCE verifier. Lock/consume that transaction on callback acceptance; omniauth.state
remains the stated exception and must still match the same transaction. | |
auth_org_entra_omniauth_pt (Auth::Org::Social::SessionsController::PT_SESSION_KEY) | ORG Entra
sign-in return target; Auth ORG | No purpose-specific server record identified; signed return target
may originate in the request | Rails cookie 14 days; absent PT follows the caller default; malformed
or invalid signed PT is rejected/sanitized by redirect validation; callback consumes and deletes the
session value | Parent ORG sign-in/Entra transaction expiry; consume on callback. |
__Host-umaxica-return-target;
{"flow_id":"<ORG sign-in flow id>","return_ref":"<server-side safe target ref>"}. Keep only a
validated same-host/path reference. | Parent OperatorSignInFlow / ORG Entra ceremony owns flow ID
and safe target binding. Lock the parent flow when accepting the first bound continuation. | |
oidc_pending_flows (one entry keyed by state JTI), and cleanup-only legacy keys oidc_code_verifier,
oidc_state, oidc_nonce, oidc_pt, oidc_max_age | RP-initiated OIDC authorization;
Base/Warp/Core/Palm/Tech/Edit and applicable Visa hosts | Visa authorization transaction keyed by
JTI/state, plus client registration and authorization outcome. OIDC_PENDING_FLOW_TTL equals
OidcStateJwt::TTL. Current pending payload contains code verifier, nonce and created time. The five
legacy keys have deletes but no active writes found. | Rails cookie 14 days; callback removes
expired pending entry and refuses; unknown state returns no flow; a valid state is consumed once.
Legacy values are cleanup-only. | Exactly OidcStateJwt::TTL / Visa authorization transaction expiry;
one-shot callback consumes it. | __Host-umaxica-oidc-authorization;
{"flow_id":"<authorization transaction id>","transaction_ref":"<JTI or transaction ref>"}. Move
verifier, nonce, target and max-age to the Visa-owned server transaction; no secret or return path
in cookie. | Visa authorization transaction stores flow ID and secrets; lock it during callback
consume/token-code exchange/final outcome commit. The accepted callback transition is the
checkpoint; parallel callback must lose without exchanging/committing twice. | |
oidc_logout_request, oidc_logout_completed | RP-initiated logout; Visa APP/ORG and RP callers |
OidcEndSessionRequest is parsed into a server-side pending logout request tied to device session;
completion is a post-logout presentation marker. Logout operation revokes device/session rows. |
Rails cookie 14 days; request absent/invalid renders failure or the explicit already-signed-out
path; completion marker is a boolean, cleared/replaced during logout. Pending request is refused if
browser/device binding mismatches. | Pending logout request expiry; completion marker only through
the immediate post-logout presentation. | __Host-umaxica-oidc-logout;
{"flow_id":"<logout transaction id>","logout_ref":"<server request ref>"}. | Logout
transaction/device session owns ID. Lock the device/session revocation writer at its irreversible
revoke commit; pending request consumption is single-use. | | email_registration_public_id,
email_registration_transaction_ref, email_registration_pt; Base APP email registration | Signed-in
email credential registration; Base APP | ClientEmailCeremonyTransaction and ClientEmail row;
transaction has its own expiry. | Rails cookie 14 days. Missing/stale ID or transaction fails the
form query and restarts/refuses; transaction expiry and browser nonce are rechecked at OTP/commit.
PT is consumed once. | Exactly the corresponding ClientEmailCeremonyTransaction expiry. |
__Host-umaxica-contact-registration;
{"flow_id":"<ceremony transaction id>","transaction_ref":"<ClientEmailCeremonyTransaction.transaction_id>"}.
Email public ID and safe return target remain server-side. | Transaction ID stored as flow ID on the
ceremony row. Lock that transaction at OTP verification and final credential commit; final commit is
the checkpoint. | | settings_telephone_registration_id,
settings_telephone_registration_transaction_ref; Base APP telephone registration | Signed-in
telephone credential registration; Base APP | ClientTelephoneCeremonyTransaction and ClientTelephone
row; transaction expiry is authoritative. | Rails cookie 14 days. Missing/invalid ref fails
validation/restarts; transaction and browser nonce are checked at OTP and commit. | Exactly the
corresponding ClientTelephoneCeremonyTransaction expiry. | Same contact-registration cookie and
schema, with the telephone transaction ref. | Transaction row owns flow ID. Lock OTP verification
and final telephone commit. | | staff_email_registration_public_id,
staff_email_registration_transaction_ref; Base ORG email registration | Signed-in email
registration; Base ORG | OperatorEmailCeremonyTransaction and StaffEmail row | Rails cookie 14 days;
server transaction expiry, actor/session, browser nonce and credential state are rechecked. Missing
or corrupt ref is refused/restarted. | Exactly the corresponding OperatorEmailCeremonyTransaction
expiry. | Same contact-registration cookie name on the ORG host; JSON contains only transaction ref
and flow ID. | Operator email ceremony transaction owns ID; lock its verify/final commit
transition. | | staff_telephone_registration_id, settings_telephone_registration_transaction_ref;
Base ORG telephone registration | Signed-in telephone registration; Base ORG |
OperatorTelephoneCeremonyTransaction and StaffTelephone row | Rails cookie 14 days; absent/stale
reference fails form/commit checks; server transaction expiry is authoritative. | Exactly the
corresponding OperatorTelephoneCeremonyTransaction expiry. | Same contact-registration cookie name
on the ORG host;
{"flow_id":"<transaction id>","transaction_ref":"<OperatorTelephoneCeremonyTransaction.transaction_id>"}. |
Operator telephone transaction owns ID; lock verify/final commit. | | Dynamic
registration_session_key, registration_transaction_session_key | Shared APP/ORG contact-registration
controller methods | Resolve to the concrete public-ID/reference keys above, not extra keys | Same
behavior as the concrete contact rows. Unknown surface fails key selection or refuses the controller
flow. | Inherit the resolved APP/ORG contact ceremony transaction expiry. | Same
contact-registration purpose cookie per host. | Same flow row and lock per contact method. | |
base_step_up_marker_locator, base_step_up_conflict; BaseStepUpTransactionMarker and
BaseStepUpIntent | Base step-up admission, retry and conflict form; Base APP/ORG | Base/OP step-up
admission transaction plus auth-state marker store; conflict payload duplicates transaction
requirements and actor/session references. Marker-store entry expiry equals admission expiry. |
Rails cookie 14 days. Locator is format-checked and marker-store lookup is bound to
transaction/actor/session. Missing/corrupt/mismatched marker rejects. Conflict payload is cleared on
continue/cancel and invalid state returns bad request. | Exactly the Base step-up admission
transaction expiry. | __Host-umaxica-step-up;
{"flow_id":"<step-up transaction id>","transaction_ref":"<transaction id>","marker_ref":"<server marker ref>"}.
Keep requirement snapshot and actor/session binding in server record. | Step-up transaction ID is
flow ID. Lock the admission/transaction record when the first successful evidence/commit crosses its
checkpoint; conflicting tabs serialize on the transaction row. | | auth_admission_browser_nonce
(BaseAdmissionBrowserBinding), including its restore on transaction conflict | Base-to-Auth
admission browser binding; Base APP/ORG | Admission/authorization transaction and
AuthAdmissionBinding hold a digest for each entry; no global nonce value is authoritative. | Rails
cookie 14 days. A new admission rotates it. Missing/invalid format, mismatch, or unavailable marker
rejects; explicit restart requires the existing value. | Exactly the AuthAdmissionBinding/admission
expiry; rotate for each new admission. | __Host-umaxica-admission;
{"flow_id":"<admission binding id>","entry_ref":"<entry ref>","binding":"<opaque nonce>"}. Cookie
stays host-only; send only digest to admission binding. | Flow ID on the binding/parent admission
record. Lock that admission binding when its first admitted transition/checkpoint commits; this is
O-3c's binding serialization point. | | enforcement_recovery_reentry, withdrawal_ceremony_reentry |
Enforcement recovery and withdrawal re-entry; relevant Auth/Base surface callers |
Enforcement/withdrawal ceremony records and account/email IDs; some re-entry steps create an
ID/digest but not every payload has a linked transaction row. | Rails cookie 14 days; values are
cleared on completion/invalid proof and readers validate shape/actor/flow. Missing or corrupt state
redirects/refuses; underlying ceremony expiry may be shorter. | Exactly each owning
recovery/withdrawal ceremony expiry. | Separate cookies by purpose:
__Host-umaxica-enforcement-reentry and __Host-umaxica-withdrawal-reentry;
{"flow_id":"<server ceremony id>","ceremony_ref":"<record ref>"}. Do not store email ID or contact
value. | Add/use each ceremony's server record for flow ID. Lock its first successful
proof/transition commit; do not use the cookie to serialize re-entry. | | passkey_challenges
(Webauthn::ChallengeStore) | Same-session WebAuthn registration/authentication/emergency/step-up
XHR; Auth/Base surface | No server row; challenge and bindings are stored as a map in session. Each
entry embeds 10-minute expiry; max 5 entries. | Rails cookie 14 days. Missing/expired challenge
raises ChallengeNotFoundError/ChallengeExpiredError; consume deletes before checking purpose, RP ID,
origin or actor, so mismatch burns it. A malformed map is treated as empty. | 10 minutes per
challenge, as currently checked by ChallengeStore. | __Host-umaxica-webauthn;
{"flow_id":"<server challenge id>","challenge_ref":"<challenge record ref>"}. Move challenge and
bindings to server-side challenge store before migration; 5 full challenge entries may exceed one
cookie. | Challenge record itself owns ID. Lock/atomic-consume the record before validation;
successful consumer is the single checkpoint winner. | | org_normal_sign_in_transaction |
Entra-identify-then-credential ORG normal sign-in; Auth ORG | No durable transaction row; payload
has Operator ID, Entra identity ID, PT, RI, status and 10-minute expiry. A Chronicle row is created
only for a halt. | Rails cookie 14 days; application checks 10 minutes and purpose/status. Missing,
invalid, halted or expired values produce binding refusal/restart. Consume deletes before second
factor/session establishment. | Current state is 10 minutes; target equals the new Auth-owned
Entra/credential transaction expiry. | __Host-umaxica-org-sign-in;
{"flow_id":"<Auth ceremony id>","ceremony_ref":"<server-side Entra/credential transaction ref>"}.
Create/use a server-side ceremony record; do not put actor ID, PT or Entra identity ID in JSON. | No
current durable row owns this state. Auth ceremony transaction must own flow ID; lock it when Entra
identity is committed and again when the selected credential consumes the continuation. | |
sign_out_notice | One-shot signed-out completion notice; Auth/Visa/Base callers of SignOutNotice |
Valkey::AuthState::SignOutNoticeStore; server TTL 5 minutes and payload includes
actor/session/state/face. | Rails cookie 14 days; consume deletes locator first, then resolves
server store. Missing/expired/unavailable store suppresses the notice; Valkey errors fail closed. |
5 minutes, matching Valkey::AuthState::SignOutNoticeStore TTL. | __Host-umaxica-sign-out-notice;
{"flow_id":"<notice store id>","notice_ref":"<opaque notice id>"}. | Notice store ID is flow ID.
Atomic consume in Valkey is the single-use lock; no extra flow checkpoint. | |
client_secret_operation | Base APP manual Secret issuance operation | ClientSecretIssuance keyed by
UUID origin_operation_id; session locator binds session_ref. Server issuance has explicit
state/expiry. | Rails cookie 14 days; invalid ID/session, completed/cancelled/expired issuance
causes a new locator or refusal. Missing locator generates a new UUID. | Exactly
ClientSecretIssuance expiry. | __Host-umaxica-secret-issuance;
{"flow_id":"<ClientSecretIssuance origin operation id>","operation_ref":"<server operation id>"}. |
ClientSecretIssuance/reservation row owns ID. Lock the issuance reservation/confirmation transition;
confirmation is checkpoint. | | staff_secret_credential_raw | Base ORG Secret credential create
retry; Base ORG | No server record currently owns the raw credential in this session path;
controller regenerates or reuses the raw secret on failed Turnstile render. | Rails cookie 14 days;
missing regenerates a raw credential, malformed data is treated as absent; raw secret persists on
retry and is consumed by create. | New server-side encrypted candidate expiry; shortest period
needed for the Turnstile retry, with an explicit server TTL. | Do not put this secret in a cookie.
Use an encrypted server-side credential ceremony candidate, then __Host-umaxica-secret-credential
with {"flow_id":"<ceremony transaction id>","candidate_ref":"<server-side candidate id>"}. |
New/identified credential ceremony record owns ID and secret. Lock it when verification/credential
commit consumes the candidate. | | secret_credential_ceremony and legacy TOTP deletes
totp_enrollment, totp_ceremony, private_key | Legacy cleanup in credential/TOTP settings concerns |
No current reader/writer found in app/ or lib/; these keys are only deleted. Current live
TOTP/secret enrollment uses dedicated ceremony transaction/candidate records. | If stale values
exist, Rails retains them for up to 14 days, but cleanup deletes them. No active absent/expired
behavior was found. | No target lifetime; no active session consumer is known. | No purpose cookie
proposed until external writers are ruled out. Treat as cleanup-only keys; verify no engine/plugin
writes before removing cleanup. | No current flow ID/checkpoint can be assigned. | |
external_authentication_ceremony_reference (cleanup-only), oidc_code_verifier, oidc_state,
oidc_nonce, oidc_pt, oidc_max_age (cleanup-only) | Old cross-provider/OIDC session reset cleanup;
Auth/Visa callers | No active app/lib writers/readers found for these exact keys; current OIDC flow
is oidc_pending_flows and current Auth admission uses its ceremony records. | Any stale value lives
up to 14 days unless a reset/cleanup path deletes it; no active reader means no current continuation
behavior. | No target lifetime while no active producer exists; if confirmed, equal the provider
ceremony expiry. | No cookie proposed absent an active producer. Keep the OIDC pending-flow proposal
for current oidc_pending_flows separate. | No active record or checkpoint found. | | private_key
(legacy TOTP delete), sign_up_flow_id (read-only fallback) | Legacy/observability-only access | No
writer found in the scanned application tree; sign_up_flow_id may be supplied by outside code and
must be checked. | Default 14-day session retention if populated; current readers either ignore
missing values or cleanup deletes the key. | No target lifetime for confirmed cleanup-only state. |
No target cookie until producer/consumer ownership is confirmed. | No ID/lock known from current
source. |

| omniauth.state (gem-managed exception) | OAuth provider round trip; Auth APP and Auth ORG |
OmniAuth gem owns the state comparison; correlated provider-attempt transaction is described in the
social/OIDC row | Rails session cookie 14 days; missing or mismatched state is rejected by the gem
callback | Retain in Rails session under O-1; lifetime follows Rails session settings and the
provider callback contract | No purpose cookie | O-1 exception; it is not the application O-3b
flow-ID authority. Correlate it with the server provider transaction; callback acceptance must
consume that transaction under its lock | | timezone | Preference update / request zone setting;
shared preference controllers across Base and applicable surfaces | Actor preference record is
authoritative; no server-side transient record is needed | Rails cookie 14 days. app/lib writes it
in preference updates and request setup, but no direct app/lib session reader was found;
missing/corrupt value therefore has no observed direct-session effect | No auth-flow lifetime
applies if the persisted preference is the source; if a browser cookie is needed, its intended
lifetime must match the preference contract, which is outside this spec | No authentication-flow
cookie proposed. Prefer the persisted preference as the source and remove this cache only after
confirming there are no out-of-tree readers. If the scope requires a cookie, existing Preference
cookies are explicitly out of scope and need an owner decision | Not an auth flow, so O-3b flow-ID
applicability is unresolved; do not invent a flow ID. No O-3c checkpoint; preference writes already
have their own owner and audit path | | language | Preference update / language resolution; shared
preference controller | Actor preference record is authoritative; no server-side transient record is
needed | Rails cookie 14 days. app/lib writes it after preference update; no direct app/lib session
reader was found. Missing/corrupt value has no observed direct-session behavior | No
authentication-flow cookie proposed. Prefer the persisted preference as the source and remove this
cache only after confirming there are no out-of-tree readers. If a cookie is required, the existing
Preference cookie scope needs review | Not an auth flow; O-3b applicability is unresolved. No O-3c
checkpoint; preference write/audit transaction is the authority | | inertia_clear_history | Inertia
history-clear navigation flag; shared Auth/Base/Visa/Warp controllers and roots | No server record;
navigation instruction | Rails cookie 14 days/session reset; writers set true and readers accept
only literal true. No app/lib deletion was found, so it can remain true until session reset.
Missing/malformed values act false | Retain in Rails session under O-2; no new lifetime contract is
accepted for this exception | No purpose cookie; explicitly retained by O-2 | Not a security flow
and no O-3b flow ID. No O-3c lock/checkpoint | | _csrf_token (implicit Rails key; not an app/lib
session[...] access) | Rails CSRF middleware; all Rails surfaces | Rails authenticity-token state,
no application flow row | Rails session cookie 14 days; middleware creates/validates it. Missing or
invalid token follows Rails CSRF rejection behavior | Remains in Rails session under D-10; lifetime
follows Rails session settings | No purpose cookie | Not an application flow ID/checkpoint; Rails
CSRF token lifecycle remains owned by Rails |

| Dynamic load_session_record(session_key) | Generic optional identity record lookup;
AuthenticationBase | No concrete key/caller was found in app/ or lib/; the method reads a
caller-supplied session key only | No current value can be assigned from observed call sites; if an
external caller supplies one, the enclosing Rails session lasts 14 days and missing/invalid ID
returns nil | No target lifetime can be set until a concrete producer/caller is found | No cookie
proposed for an uncalled generic accessor; resolve out-of-tree use first | No O-3b flow ID or O-3c
checkpoint can be assigned without a concrete flow |

## Direct access-site index (app/ and lib/)

The purpose table above groups aliases by flow. This index gives every non-comment direct bracket
read/write and `session.delete(...)` call found by the source scan, with its current path and line.
A `write` is syntactic assignment; a `read` is a non-assignment access; `delete` clears state.
Dynamic expressions (for example `session_key`, `surface_key`, or a constant) resolve through the
owner named in the purpose table. The index intentionally excludes the serialized session-row
`:revoke` hash and ORM `session.update!` calls. It does not list implicit Rails CSRF storage or
OmniAuth gem-internal `state` operations.

| Key expression                                                                 | Access | Location                                                                            | Source line                                                                                                             |
| ------------------------------------------------------------------------------ | ------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
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

Counts below are estimated purpose-cookie counts after consolidation of keys that share one actual
flow, excluding the three Rails-session exceptions and excluding already-purpose-specific cookies.
Ranges reflect callers shared through concerns and a few legacy producer questions called out above.
They are planning estimates, not measurements of a deployed request header.

| Host     | Estimated flow-purpose cookies | Largest expected cookie | Basis / unresolved check                                                                                                            |
| -------- | -----------------------------: | ----------------------: | ----------------------------------------------------------------------------------------------------------------------------------- |
| Auth APP |                          11–15 |                  1.5 KB | Sign-in, sign-up, social, OIDC, session-limit, MFA/checkpoint, contact and WebAuthn; includes secret-state moves to server records. |
| Auth ORG |                           9–13 |                  1.5 KB | Sign-in, Entra continuation, social/OIDC state, session-limit/checkpoint and WebAuthn.                                              |
| Visa APP |                            6–9 |                  1.0 KB | Sign-in/session-limit, OIDC authorization/logout, return target and completion notice.                                              |
| Visa ORG |                            6–9 |                  1.0 KB | Same purpose families as Visa APP with ORG-specific flow rows.                                                                      |
| Base APP |                           7–11 |                  1.5 KB | Admission, step-up, contact registration, Secret issuance, OIDC and sign-out presentation.                                          |
| Base ORG |                           7–11 |                  1.5 KB | Admission, step-up, contact registration, secret ceremony, OIDC and sign-out presentation.                                          |
| Base COM |                            1–3 |                  1.0 KB | Locale/timezone state plus any shared return/notice caller found at implementation time.                                            |
| Warp APP |                            2–5 |                  1.0 KB | OIDC continuation, return/notice and any shared sign-in/session-limit caller.                                                       |
| Warp COM |                            1–4 |                  1.0 KB | Locale/timezone and shared continuation/notice callers.                                                                             |
| Warp ORG |                            2–5 |                  1.0 KB | OIDC continuation, return/notice and any shared sign-in/session-limit caller.                                                       |
| Core APP |                            3–6 |                  1.0 KB | OIDC, sign-in/session-limit, return target and notice callers.                                                                      |
| Core ORG |                            3–6 |                  1.0 KB | ORG equivalents; confirm actual OIDC host inclusion.                                                                                |
| Palm APP |                            3–6 |                  1.0 KB | OIDC, sign-in/session-limit, return target and notice callers.                                                                      |
| Tech ORG |                            3–6 |                  1.0 KB | OIDC and shared sign-in/session-limit/return callers.                                                                               |
| Edit ORG |                            3–6 |                  1.0 KB | OIDC and shared sign-in/session-limit/return callers.                                                                               |

Design target: each encrypted purpose cookie stays below 1,536 bytes; typical locator-only cookies
should be below 800 bytes. The new per-purpose JSON should carry only a flow_id, a server record
reference and (where required) one opaque binding. The current passkey_challenges session map and
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
new-flow replacement/replay (AC-11/AC-12). The exact AC list is retained from the accepted spec;
there is no AC-13.
