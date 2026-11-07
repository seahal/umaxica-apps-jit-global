# Browser Flow State in Purpose-Specific Encrypted Cookies

Status: accepted by the owner on 2026-11-06. Work order 1 and the I-1 server-record design are
complete. Work order 2 is in progress: request tests for the D-12 restart path have been added, but
AC-13 coverage is partial and the sign-in incident tests for AC-1 to AC-8 have not been completed.
Purpose-cookie migration and the D-10 session guard have not started; no behavior migration is
claimed.

Predecessor: `plans/backlog/2026-11-04-rails-session-to-purpose-cookies.md`.

## Why

Sign-in and related flows keep browser-side flow state in the single Rails session cookie
(`config/initializers/session_store.rb`, `:cookie_store`, `JitSessionCookieConfig`, one host-only
cookie, `expire_after: 14.days`). Keys have no lifetime of their own, so state from an earlier flow
stays for up to 14 days and is read by a later, unrelated flow.

Observed on 2026-11-06 in development (`log/development.log`, `log/development.access.jsonl`):

1. A sign-in completed at 06:33 UTC.
2. A new sign-in began at 06:45 UTC through Base. The entry and ceremony binding succeeded and
   created a fresh Auth ceremony (id 57, no OTP, no evidence).
3. `GET /sign/in?ri=jp` then returned 409 "この画面は古くなっています。最初からやり直してください。"
   with `sign.refused` `reason_code: missing_binding`.

Cause (source reading): `SignInPhaseBindingControllerSupport#enforce_sign_in_phase_binding!` found a
current flow through `SignInCycleLocator`, which reads `session[:app_sign_in_flow_locator]` left by
the earlier flow. The new request carried no flow binding for it, so it was refused as stale. The
same class of failure is behind earlier "start over" refusals, OmniAuth `csrf_detected` that
disappeared after deleting cookies, and cross-tab interference.

## Owner decisions (2026-11-06)

- Move everything in one change; no interim "fresh entry supersedes leftover state" patch.
- One cookie per purpose. When two tabs run the same kind of flow, the newer one wins. The older tab
  gets the existing restart guidance, not an error page that requires deleting cookies.
- Earlier direction (2026-11-04): keep the Rails session for the CSRF token only; every other use
  gets its own Rails encrypted cookie, with only the lifetime its flow needs.

## Scope

In scope: every `session[...]` read or write in `app/` and `lib/` on Auth, Visa, Base, Warp, Core,
Palm, Tech and Edit, except the Rails CSRF token. A static count on 2026-11-06 found about 60
distinct keys. The largest groups are the sign-in flow locator (`SignInCycleLocator`), the sign-up
state (`SignUpSessionState`), the social OAuth group (`SOCIAL_*`), the session-limit gate, re-entry,
OIDC pending flows and logout, contact registration transaction references, step-up markers, the
browser nonce, sign-out notices and bulletins, `inertia_clear_history` and `timezone`.

Out of scope: DBSC; the Preference cookies; `__Host-auth_sid` and other cookies that are already
purpose-specific (they are listed in the inventory but not redesigned); changing what any flow
means.

## Design rules

- D-1 Owner per purpose. Each cookie purpose has exactly one owner (a concern or value object) that
  fixes the cookie name, lifetime, JSON schema, and the read, write and clear methods. Controllers
  do not call `cookies.encrypted` directly.
- D-2 Format. `cookies.encrypted` with a JSON value. With `config.load_defaults(8.2)`, Rails embeds
  the purpose `cookie.<name>` and the expiry (`expires_in` / `expires_at`) inside the encrypted
  message (verified in the vendored Rails source,
  `actionpack/lib/action_dispatch/middleware/cookies.rb`, `cookie_metadata` and
  `EncryptedKeyRotatingCookieJar#commit`). The server rejects a value past its embedded expiry or
  copied under another name even if the browser still sends it. Values are identifiers, references,
  nonces' digests and timestamps only: no secrets, OTPs, tokens or contact values. No YAML or
  Marshal.
- D-3 Attributes. `__Host-` prefix, `Secure`, `Path=/`, no `Domain`, `HttpOnly`. `SameSite=Lax`
  unless the inventory shows a purpose needs otherwise; record the reason per purpose.
- D-4 Lifetime. Each purpose's lifetime equals the server-side lifetime of the record it points to
  (for example the authorization transaction or OTP window), never longer. Purposes with no
  server-side record get the shortest lifetime that completes the step.
- D-5 Reference, not copy. Where server-side state exists, the cookie holds only a reference and a
  binding nonce; the server record stays the authority. The cookie never decides a state transition
  by itself.
- D-6 Newer wins at start. Starting a flow deletes and re-creates that purpose's cookie (O-3a). A
  request whose page binding or reference no longer matches the cookie gets the existing restart
  guidance and clears nothing else.
- D-7 Fresh entry. A new Base-issued admission (`entry_ref`) starts a fresh flow and replaces any
  leftover cookie of the same purpose; a leftover cookie can never block a fresh entry.
- D-8 Clear on finish. Completion, cancellation and refusal that ends a flow delete that purpose's
  cookie. Sign-out deletes all flow cookies of the host.
- D-9 Missing or invalid cookie. Missing, expired, undecryptable or wrong-schema values are treated
  as "no state" and lead to the restart guidance (`adr/invalid-browser-credential-recovery.md`),
  not 500. Log a fixed reason code, never the value.
- D-10 Rails session. After migration it holds only the CSRF token, the OmniAuth `state` (O-1),
  `inertia_clear_history` (O-2), and `timezone` and `language` (I-2). A static guard test fails on any new `session[...]` use outside the
  allowlist.
- D-12 Restart destination (absorbs `docs/backlog/2026-10-27-sign-flow-safe-termination-and-restart.md`,
  owner 2026-11-06). The restart guidance is a page, not a dead end: it shows one server-selected link
  back to the entry that can start the flow again. For Auth and Visa flows this is the originating
  surface's Base sign entry (`/sign` on that surface's Base host), because a context-free Auth URL is
  not a valid entry. A refused GET or HEAD changes no state: it neither deletes cookies nor resets the
  session nor revokes anything (`docs/checklists/authentication-flow-integrity.md` FLOW-2/4). The
  leftover purpose cookie is replaced when the new entry starts (D-7, O-3a). Cooldowns and other
  server-side protections are untouched. The link target is fixed per surface, never taken from the
  request.
- D-11 No compatibility layer. Existing session values are not migrated; an in-flight flow at
  deployment restarts once (`generic/no-compatibility-layer.mdc`). Record this in the release notes.

## Owner decisions on the former open points (2026-11-06)

- O-1 OmniAuth `state`: follow the gem. OmniAuth keeps its `state` in the Rails session as the gem
  does; this is a documented exception to D-10. Our own social keys (`SOCIAL_*`) still move to
  purpose cookies.
- O-2 `inertia_clear_history`: documented exception to D-10; it stays in the Rails session.
- O-3 Granularity: one encrypted cookie per purpose, even when a host ends up with many cookies. Do
  not group purposes into one cookie to save space. The inventory still reports the count and size
  per host so that a real browser limit is found before release, not after.
- O-3a New flow means a new cookie: starting a new flow of a purpose deletes that purpose's cookie
  and sets a new one. A cookie is never updated in place to represent a different flow.
- O-3b Flow identifier: every purpose cookie carries the identifier of the flow it belongs to (a
  random, single-use flow ID that also exists on the server-side record). Each request compares the
  cookie's flow ID, the page's binding and the server record; any mismatch is the restart guidance.
- O-3c Race between tabs: when two tabs run the same purpose concurrently, the server, not the
  cookie, decides. The first flow to reach its checkpoint (the first server-side commit that moves
  the flow past its entry phase) wins, under a lock on the server-side record that serializes the
  two. The other flow is refused with the restart guidance and changes nothing. This refines D-6:
  "newer wins" applies to starting a flow; once both have started, "first to the checkpoint wins".
- O-4 `secret_key_base` rotation: no rotation support for flow cookies. Rotation invalidates them
  and in-flight flows restart.

## Owner decisions on the inventory (2026-11-06)

Inventory: `specs/browser-flow-state-cookies/inventory.md` (Codex, 2026-11-06), reviewed by Claude Code.

- I-1 New server-side records are authorized for state that today exists only in the Rails session:
  the post-authentication sign-in sequence (`SignInSequenceCarrier`), the ORG Entra-then-credential
  continuation (`org_normal_sign_in_transaction`), WebAuthn challenges (`passkey_challenges`), the
  ORG Secret credential retry candidate (`staff_secret_credential_raw`) and the email sign-in dummy
  address. I-5 supersedes the candidate-record portion: ORG Secret is generated after successful
  creation and has no retry candidate row. The remaining records use additive migrations only (new
  tables; no change to existing tables or data), each with an explicit expiry and a purge. The
  table shapes are written into this spec and reviewed before any migration is created. Raw secrets
  never go into a cookie or server-side retry record.
- I-2 `timezone` and `language`: out of scope for this change. They stay in the Rails session as an
  exception to D-10, to be handled with Preference work.
- I-3 Cleanup-only legacy keys with no producer in `app/` or `lib/` (old OIDC and TOTP keys,
  `external_authentication_ceremony_reference`, `secret_credential_ceremony`, `private_key`, the
  `sign_up_flow_id` fallback read) and the uncalled `AuthenticationBase#load_session_record` are
  removed. No other application writes this application's encrypted session cookie, so no
  out-of-tree producer check is needed.
- I-4 Request header size: before release, measure the real cookie header on Auth APP with every
  purpose active and compare it with the reverse proxy and Puma request-header limits. The inventory
  estimates up to about 23 KB at the 1.5 KB-per-cookie ceiling.
- I-5 ORG Secret credential disclosure: generate the raw credential only after a valid Turnstile
  response and successful create request. Do not persist it in Rails session, a cookie, a retry row or
  logs. The create response is the one-time disclosure. The Base ORG `new` page no longer generates
  or previews the secret; after success it shows the returned value. A failed Turnstile/create
  attempt stores no raw candidate. Remove `staff_secret_credential_raw` during the relevant
  implementation stage; do not create an `OperatorSecretCredentialCandidate` table.

## Server-side records

These additive records make each purpose cookie a locator; the row and its owning ceremony/session
remain authoritative. The common cookie JSON is {"flow_id":"…","binding_nonce":"…"}.
flow_id is 32 random bytes encoded as unpadded base64url (string(43)), single-use and unique in its
table. Each record stores generation_id uuid NOT NULL for the O-3c checkpoint generation and
binding_nonce_digest string(64) NOT NULL, a SHA-256 digest of the separate
random nonce; the nonce itself is never stored server-side. Cookie expiry equals the row's expires_at.
Each row has indexed purge_eligible_at, set to its expiry or terminal transition time when no retry
remains. RetentionPurgeJob runs every 15 minutes and must include these models in its retainable
list. Expired rows are refused immediately while physical deletion waits for the next purge pass.
These are transient records, not audit history, so the existing set-based purger is appropriate.

Persisted lifecycle uses realm-local reference tables and non-null foreign keys, matching the
repository's state-table convention: state_id bigint NOT NULL points to a record-specific state
table. The independent O-3c claim axis uses checkpoint_status_id bigint NOT NULL and a realm-local
BrowserFlowCheckpointStatus lookup with OPEN and CLAIMED. These are separate axes: state_id describes
the flow lifecycle; checkpoint_status_id records which flow won the generation race. WebAuthn
purpose_id bigint NOT NULL points to a realm-local WebauthnChallengePurpose lookup. Each other table
has a fixed purpose by ownership, so it has no redundant purpose_id. There are no string state enums
or NULL-encoded states.

The checkpoint claim lookup is distinct from lifecycle state because a flow keeps its claim after it
advances or completes; the lifecycle state can then describe the later transition independently.
Each flow row has checkpoint_status_id NOT NULL (initially OPEN). The database enforces one winner
with a partial unique index on parent, purpose and generation_id, filtered to the CLAIMED reference
ID. Use stable lookup IDs OPEN=10 and CLAIMED=20 so the partial index can filter on
checkpoint_status_id = 20; the reference row still supplies the readable status and FK. A losing
flow is refused without changing its row. The child's checkpoint timestamp, if retained
for operations, is metadata only; no code branches on whether a timestamp is NULL. WebAuthn's index
also includes purpose_id; other tables have a fixed purpose. Parent/session is always locked before
the child row.

Create one BrowserFlowCheckpointStatus reference table in each owning database (`op_base_app`,
`op_base_org`, and `rp_base_org`) with the same stable OPEN=10 and CLAIMED=20 IDs. CLAIMED is
irreversible for that generation and remains on the winning row until purge; a later independent
entry receives a new generation rather than reopening the old one.

Fresh-entry behavior reconciles D-7/O-3a with O-3c as follows. Every fresh Base admission creates a
new flow_id and replaces that purpose cookie. Under the parent lock, it joins the existing open
generation_id if no flow in that generation has claimed a checkpoint; otherwise it creates a new
generation. It does not replace or mutate the old child row. An old-tab request already sent with
its old cookie may still reach the shared checkpoint and win. After the browser accepts the new
Set-Cookie, a later old-page request sends the new flow_id with its old page binding and is refused;
it cannot reach the checkpoint. If an earlier generation already has a winner, a fresh entry starts
a new generation and the old generation remains closed.

| Record and database | Proposed columns and constraints | Foreign keys and owner | O-3c lock/checkpoint | Expiry and purge |
|---|---|---|---|---|
| ClientSignInSequence in op_base_app (Auth APP only) and OperatorSignInSequence in op_base_org (Auth ORG) | Common columns plus id bigint PK; auth_ceremony_session_id bigint NOT NULL; actor_public_id string(21) NOT NULL; entry_method string NOT NULL; method string NOT NULL; participant_id bigint NOT NULL; safe_return_path text and mfa_challenge_id string(21), session_limit_gate_id string(21) nullable optional data; state_id bigint NOT NULL; checkpoint_status_id bigint NOT NULL; issued_at, expires_at, purge_eligible_at, created_at, updated_at datetime NOT NULL. APP and ORG are fixed by their respective tables. Lifecycle lookups are ClientSignInSequenceState and OperatorSignInSequenceState, using current SignInSequence::STATES; SignInSequenceParticipant is a reference table with NONE, GUARDRAIL, CHECKPOINT, DASHBOARD. Partial unique index (auth_ceremony_session_id, generation_id) where checkpoint status is CLAIMED. | OP/Auth-side op_base_app / op_base_org, because this is post-authentication Auth ceremony state and shares the existing Auth ceremony session. Same-database FK to client_auth_ceremony_sessions.id / operator_auth_ceremony_sessions.id with ON DELETE CASCADE; state_id, checkpoint_status_id and participant_id reference same-database lookup tables. Actor public ID is a logical reference because principal rows live in separate zenith databases. Source audit found no COM authentication caller: COM sign-in routes are retired and SignInSequenceCarrier is used only with Auth APP/ORG surfaces. The new tables therefore exclude COM. | Lock parent Auth ceremony session, then child. First transition from entry to its first post-auth participant claims the generation; the unique index is the backstop. safe_return_path is optional navigation data, not lifecycle state. Optional challenge/gate identifiers are references only; current production code has no transition branch on their presence. state_id alone controls lifecycle. | Preserve carrier sliding 15-minute TTL: issuance sets expires_at; accepted state advances refresh it, reads do not. Keep flow_id while advancing and refresh cookie expiry with the row. Purge eligibility follows current expiry, or terminal transition time. Add models to RetentionPurgeJob. |
| OperatorNormalSignInTransaction in op_base_org | Common columns plus id bigint PK; auth_ceremony_session_id bigint NOT NULL; operator_public_id string(21) NOT NULL; entra_identity_public_id string(21) NOT NULL; pt text and ri string nullable optional navigation/region data; return_target_kind_id and region_source_id bigint NOT NULL referencing OperatorNormalSignInReturnTargetKind (DEFAULT, BOUND) and OperatorNormalSignInRegionSource (CURRENT, EXPLICIT); state_id bigint NOT NULL referencing OperatorNormalSignInTransactionState; checkpoint_status_id bigint NOT NULL; issued_at, expires_at, purge_eligible_at, created_at, updated_at datetime NOT NULL. Purpose is fixed by this table. Partial unique index (auth_ceremony_session_id, generation_id) where checkpoint status is CLAIMED. | OP/Auth-side op_base_org, owned by the Auth ORG authentication ceremony. FK to operator_auth_ceremony_sessions.id (ON DELETE CASCADE) and local state/checkpoint/return-target/region-source lookups. Operator and Entra identity live in org_zenith; their public IDs are logical references, not cross-database FKs. Halt accounting remains in OperatorChronicle. pt and ri affect navigation/region context only; they do not decide authentication state. Branch on explicit mode lookups rather than their nullness. | Lock operator auth ceremony session, then transaction row. Successful Entra continuation claims the generation before the credential stage; credential consumption is a locked transition to the terminal lifecycle state before session establishment. | Preserve the current absolute 10-minute expiry from Entra success. Do not extend on reads. Purge on expiry or terminal transition. Add the model to RetentionPurgeJob. |
| ClientWebauthnChallenge in op_base_app and OperatorWebauthnChallenge in op_base_org | Common columns plus id bigint PK; auth_ceremony_session_id bigint NOT NULL; challenge string NOT NULL; purpose_id bigint NOT NULL; surface, rp_id, origin string NOT NULL; actor_global_key string NOT NULL (the explicit unknown-actor value is "unknown"); state_id bigint NOT NULL referencing realm-local WebauthnChallengeState with ISSUED, CONSUMED, EXPIRED; checkpoint_status_id bigint NOT NULL; issued_at, expires_at, purge_eligible_at, created_at, updated_at datetime NOT NULL. Purpose lookup values: REGISTRATION, AUTHENTICATION, EMERGENCY_SIGN_IN, STEP_UP. Partial unique index (auth_ceremony_session_id, purpose_id, generation_id) where checkpoint status is CLAIMED. Keep the existing cap of five live challenges per ceremony session; issue under the parent lock, expire stale rows, then evict the oldest live row at the cap. | OP/Auth-side per realm because challenge verification belongs to the Auth ceremony. FK to matching client/operator auth ceremony session (ON DELETE CASCADE) and local state/purpose/checkpoint lookup tables. actor_global_key has no FK: it can be the explicit unknown sentinel, and a real actor's credentials live in another database. | Lock parent then challenge row. The first challenge consume in a generation/purpose claims the checkpoint. | Preserve 10-minute absolute TTL; reads do not extend it. Add to RetentionPurgeJob; expired or consumed challenges become purge-eligible immediately. |
| ClientSignInDummyEmailState in op_base_app | Common columns plus id bigint PK; auth_ceremony_session_id bigint NOT NULL; email_address text NOT NULL with Active Record Encryption at rest; state_id bigint NOT NULL referencing ClientSignInDummyEmailStateStatus (PENDING, CONSUMED, EXPIRED); checkpoint_status_id bigint NOT NULL; issued_at, expires_at, purge_eligible_at, created_at, updated_at datetime NOT NULL. No contact FK because this represents an address without a usable ClientEmail. Partial unique index (auth_ceremony_session_id, generation_id) where checkpoint status is CLAIMED. | OP/Auth-side op_base_app, as a continuation of APP email OTP; FK to client_auth_ceremony_sessions.id (ON DELETE CASCADE) and local state/checkpoint lookups. The submitted address is encrypted for OTP form re-render and never appears in a cookie or log. | Lock client auth ceremony session, then row. First validated address submission claims the generation. Invalid-code attempts in that same OTP flow use the existing row under OTP attempt/rate limits. | expires_at is the OTP challenge's 10-minute maximum, shortened to the parent ceremony deadline. Add to RetentionPurgeJob; purge at expiry or after terminal verification. |

The persisted lifecycle states are represented by these realm-local status references: Client and
Operator SignInSequenceState use the existing SignInSequence::STATES; OperatorNormalSignInTransactionState
uses AWAITING_CREDENTIAL, CONSUMED, HALTED, EXPIRED; WebauthnChallengeState uses ISSUED, CONSUMED,
EXPIRED; ClientSignInDummyEmailStateStatus uses PENDING, CONSUMED, EXPIRED. BrowserFlowCheckpointStatus
uses OPEN and CLAIMED. WebauthnChallengePurpose is a separate reference table for the four purposes
above. Purpose is fixed by the table for the other records, so no purpose column is needed there.

Optional values were checked against their readers. safe_return_path, pt and ri are optional
navigation/region data, not lifecycle state. For ORG continuation, the explicit return-target and
region-source references distinguish DEFAULT/BOUND and CURRENT/EXPLICIT, so code branches on those
references, not on NULL. mfa_challenge_id and session_limit_gate_id are optional references; current
production code writes/exposes them but does not branch on their presence to transition the sequence.
actor_global_key is always non-null; "unknown" is the explicit sentinel and never means NULL.

The WebAuthn consume ordering preserves current one-time burn behavior in an atomic transition: a
found row becomes EXPIRED if its deadline has passed, otherwise CONSUMED, before binding checks
return or raise. Purpose, surface, RP ID, origin, actor, expiry and replay failures cannot reuse it.
Do not delete the row before resolving and locking its flow_id. The cryptographic assertion/attestation
verifier still runs after the challenge is burned, as it does now.

I-5 means there is no server-side ORG Secret candidate record. Base ORG new no longer generates or
previews a raw value. On a successful Turnstile-protected create, the credential operation generates
the raw secret, writes only its verifier/credential data, and returns the raw value in the one-time
success response. Failure never stores or discloses it. A lost success response cannot recover that
raw value; the operator must replace the credential through its existing management path. No raw
value enters Rails session, a cookie, or logs.

Before: the four remaining state types exist only in Rails session values; no corresponding
server-side rows exist. After, each cookie has only flow_id and nonce, while its row is authoritative.
The parent ceremony/session supplies the browser binding. Flow IDs and nonces are generated at start;
actor/Entra references, entry method, return target and WebAuthn bindings come from validated input;
lifecycle and checkpoint states come only from server transitions. The dummy address is the
already-normalized address.

Before: {"sign_app_in_email_authentication":{"id":null,"address":"<submitted address>"}}
After cookie: {"flow_id":"<random single-use id>","binding_nonce":"<random nonce>"}
After row: {"flow_id":"<same id>","binding_nonce_digest":"<SHA-256>",
            "email_address":"<encrypted>","state_id":"<PENDING FK>",
            "checkpoint_status_id":"<CLAIMED FK>","expires_at":"<OTP expiry>"}

These are new private server-side contracts: migrations are additive, no existing rows are rewritten,
and no client other than the purpose-cookie owner consumes the rows. I-3 cleanup-only keys and
AuthenticationBase#load_session_record remain untouched until their implementation stage.

## Work order

1. Inventory (no behavior change): for every key, its writer, readers, flow, host, server-side
   record, current lifetime, intended lifetime, failure behavior and target purpose cookie. Record
   it in `specs/browser-flow-state-cookies/inventory.md`, including the cookie count and size per
   host (O-3).
2. Purpose owners and tests first: write the request tests for AC-1 to AC-8 and AC-13 against the
   current code and confirm the incident tests fail. AC-13 covers the D-12 fixed Base `/sign` link,
   successful restart from that link, and that a refused GET/HEAD changes no cookie, Rails session,
   server record or cooldown.
3. Migrate flow by flow (sign-in, sign-up, social, OIDC, contact registration, step-up, others),
   each with its tests green, then remove the session keys. Include D-12/AC-13 in the refusal paths:
   GET/HEAD refusals render the fixed surface Base `/sign` restart link and leave state unchanged.
4. Add the static guard (D-10) and update the owning docs and ADRs.

## Acceptance

- AC-1 Incident: after a completed sign-in in one browser, a new sign-in started from Base reaches
  the method selection page; no 409.
- AC-2 Abandoned flow: a sign-in or sign-up abandoned at any step does not block a new one started
  from Base, for APP and ORG.
- AC-3 Two tabs: starting the same flow in a second tab makes the first tab's next request show the
  restart guidance; the second tab completes normally.
- AC-4 Expiry: a purpose cookie presented after its embedded expiry is ignored by the server even
  when the browser sends it (test by replaying the old cookie value).
- AC-5 Integrity: a value copied under another purpose's name, altered, or encrypted with another
  key is ignored and leads to restart guidance; no 500.
- AC-6 Isolation: cookies are host-only with the `__Host-` prefix; no flow cookie is readable or
  writable by another surface host.
- AC-7 Sign-out removes every flow cookie on that host.
- AC-8 Google and Apple social sign-in complete repeatedly in one browser without deleting cookies,
  including after an abandoned social attempt (the earlier intermittent `csrf_detected`).
- AC-9 The Rails session contains only the CSRF token, the OmniAuth `state`,
  `inertia_clear_history`, `timezone` and `language`; the static guard enforces it.
- AC-11 Race: two tabs submit the same purpose's step concurrently (independent connections);
  exactly one reaches the checkpoint and proceeds, the other gets the restart guidance, and the
  server record shows one winning flow.
- AC-12 New flow: starting a new flow of a purpose replaces the cookie (old flow ID no longer
  accepted), even when the old flow was mid-step.
- AC-13 Restart: every refusal that shows the restart guidance on Auth APP/ORG and Visa APP/ORG
  includes the fixed Base sign entry link of its surface; following it starts a new flow that reaches
  the first page; the refused GET itself changed no cookie, session or server record.
- AC-10 No cookie value contains an OTP, token, secret or contact value; logs contain reason codes
  only.
