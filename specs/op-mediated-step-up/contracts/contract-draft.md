# Contract draft (plan unit 0)

Date: 2026-11-04. Revision 13 (O-9 to O-12 designs accepted with conditions in
`revision-13-design.md`; revision 12: owner decisions O-11 and O-12; owner decision O-11, the Auth
and Base split; revision 11: section 9 retained-writer correction; owner decisions O-9 and O-10
recorded in section 12, designs pending; revision 10: section 9 attribution is a union of the
retained column and commit facts; revision 9: the owner resolved the section 4 / section 8
attempt-rejected conflict; revision 8 codifies the finite audit-code vocabularies for
implementation; revision 7 is the owner-accepted persistence amendment after the unit 1 blocker;
revision 6 answered `review-7.md` RV-97 and RV-98, fixed the audit payloads and the lifetimes;
revision 4 applied the owner's choice of the signed client-assertion expectation instead of
`id_token_hint`). Status: accepted. The owner accepted the revision-8 code vocabularies on
2026-11-03 with `dispatch_started` added, the revision-9 attempt-rejected rule and the revision-10
attribution union the same day, and the remaining requirements at revision 7. "Verified" means read
in the tree in this session; everything else is a proposal. Companions: `consumer-inventory.md`
(revision 3) and `adr-amendment-drafts.md`.

## 1. Fixed values

- Class (`acr`): `https://visa.umaxica.app/acr/reauthentication`. Owner decisions 2026-11-03: HTTPS
  form, host `visa.umaxica.app`, no page served, one value for both realms (an identifier only; it
  grants no cross-realm access). Compared byte for byte; never routed through
  `AuthorizationTokenClaims#normalize_acr`, which defaults blank to `aal1` and downcases (verified,
  `authorization_token_claims.rb:58-61`).
- Window: 300 seconds, predicate `auth_time <= now < auth_time + 300`, no skew allowance. JWT `exp`
  (leeway 30 seconds today) is validated separately and is not the window. Old 15 minute constants
  do not govern the new verifier; bootstrap, full reauthentication and unrelated lifetimes are not
  rewritten.
- Event: `oidc_auth_time`, `oidc_acr`, `oidc_amr` of the per-client grant usage, read as one
  snapshot under the lock issuance already takes (verified, `oidc_refresh_token_issuer.rb:89-107`).

## 2. Canonical authorization request

The RP start action sends to its realm's OP authorization endpoint: `response_type=code`,
`client_id`, the exact registered step-up redirect URI (section 11), `scope`, `state`, `nonce`,
`code_challenge` with `S256`, `prompt=login` and
`claims={"id_token":{"acr":{"essential":true,"value":"https://visa.umaxica.app/acr/reauthentication"},"auth_time":{"essential":true}}}`.
`acr_values` is not sent; a request carrying a conflicting `acr_values` is invalid (local rule; OIDC
Core 5.5.1.1 leaves the combination unspecified). `id_token_hint` is not used (owner decision
2026-11-03, section 6). Access-token claims match the ID Token. Visa app and Visa org both add
`claims` and `acr_values` to their allowlists (both omit them today; verified,
`visa/app/authorization_base_controller.rb:269-277`,
`visa/org/authorization_base_controller.rb:234-242`). Discovery (`claims_parameter_supported`,
`acr_values_supported`) is published only at activation, per realm.

## 3. Protected-resource challenge

Only for a request whose session, authentication and authorization prerequisites are valid but whose
step-up evidence is absent or insufficient:

```
HTTP/1.1 401
WWW-Authenticate: Bearer error="insufficient_user_authentication",
  error_description="step-up authentication is required",
  acr_values="https://visa.umaxica.app/acr/reauthentication", max_age="300"
Cache-Control: private, no-store
```

`Bearer` because the cookie carries the OP access token whose event is evaluated; the header is a
signal and never exposes the token to JavaScript. Non-HTML clients receive a localized plain-text
body (explicit translation key); a full-page HTML navigation receives a rendered page with the
explicit entry. A 401 challenge is not an Inertia external-location response.

## 4. Outcome table

Rows do not overlap. "No state change" means no write to any step-up state, outbox or credential,
with one exception (owner decision 2026-11-03, resolving the conflict with section 8 found in unit
4): at the RP callback, when the request's state matches a known RP state, a refusal writes exactly
one `step_up.attempt_rejected` outbox row in its own transaction and changes nothing else. Mapping:
rows (1) with a known state and a browser-binding mismatch give `foreign_browser`; rows (1) with a
known state and a session, issuer or `sid` mismatch give `state_mismatch`; row (2) gives
`duplicate_callback`. An unknown state, an expired flow or a logged-out flow writes nothing. The
partial unique index of section 8 bounds the rows to one per state and reason; a conflicting insert
is ignored, not an error. At the RP callback the rows are evaluated in order: correlation first,
then the source state, then the error or code.

| Boundary                      | Condition                                                                                                                      | Response                                                                                                                                                                                                                                                                                                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Protected resource            | prerequisites valid, evidence absent or insufficient                                                                           | 401 with the challenge of section 3                                                                                                                                                                                                                                                                                                                               |
| Protected resource            | no valid session                                                                                                               | existing missing-login branches: JSON 401, Inertia 409 with `X-Inertia-Location`, HTML redirect (`browser_rp_authentication.rb:414-433`)                                                                                                                                                                                                                          |
| Protected resource            | authorization denied                                                                                                           | 403                                                                                                                                                                                                                                                                                                                                                               |
| Protected resource            | verifier dependency unavailable (database clock, configuration)                                                                | 503, never a pass; missing required configuration fails at its owning startup boundary                                                                                                                                                                                                                                                                            |
| `GET` or `HEAD /verification` | no valid session                                                                                                               | missing-login branches                                                                                                                                                                                                                                                                                                                                            |
| `GET` or `HEAD /verification` | valid session                                                                                                                  | entry page (`HEAD`: headers only), `Cache-Control: private, no-store`, no write                                                                                                                                                                                                                                                                                   |
| `POST /verification`          | CSRF token invalid                                                                                                             | the existing Base handler (`rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure`, verified at `base/app/application_controller.rb:63` and org l.64; it re-raises for non-JSON, `sign_error_responses.rb:68`, and returns JSON 403, l.70-71). The routed controller's status is fixed by a test in implementation. No state change |
| `POST /verification`          | Origin or Fetch Metadata not same-origin                                                                                       | 403, no state change                                                                                                                                                                                                                                                                                                                                              |
| `POST /verification`          | no valid session                                                                                                               | missing-login branches, no state change                                                                                                                                                                                                                                                                                                                           |
| `POST /verification`          | valid                                                                                                                          | RP state PENDING created, 303 to the OP authorization URL                                                                                                                                                                                                                                                                                                         |
| OP authorization              | client or redirect URI invalid                                                                                                 | error page, no redirect, no state change (OIDC Core 3.1.2.6)                                                                                                                                                                                                                                                                                                      |
| OP authorization              | no active OP session, or the client has no live grant under it                                                                 | redirect with `login_required`, no OP context created                                                                                                                                                                                                                                                                                                             |
| OP authorization              | malformed request after validation                                                                                             | redirect with `invalid_request`, no OP context created                                                                                                                                                                                                                                                                                                            |
| OP authorization              | essential class not satisfiable for the owner                                                                                  | redirect with `unmet_authentication_requirements`; OP context to FAILED                                                                                                                                                                                                                                                                                           |
| OP authorization              | user cancels at Auth                                                                                                           | redirect with `access_denied`; OP context to CANCELLED                                                                                                                                                                                                                                                                                                            |
| RP callback (1)               | state unknown, browser binding, session, issuer or `sid` mismatch, expired or logged-out flow                                  | 400 invalid-callback refusal, no state change (current order verified, `oidc_callback.rb:27-41`)                                                                                                                                                                                                                                                                  |
| RP callback (2)               | correlated, source state is not PENDING (DISPATCHING or terminal), with code or error                                          | 409 terminal ceremony conflict, no dispatch, no state change                                                                                                                                                                                                                                                                                                      |
| RP callback (3)               | correlated, PENDING, error `access_denied`                                                                                     | RP state to CANCELLED, back to the return target                                                                                                                                                                                                                                                                                                                  |
| RP callback (3)               | correlated, PENDING, any other OIDC error                                                                                      | RP state to REFUSED, back to the return target                                                                                                                                                                                                                                                                                                                    |
| RP callback (3)               | correlated, PENDING, code present                                                                                              | RP state to DISPATCHING, then the token exchange (section 6)                                                                                                                                                                                                                                                                                                      |
| OP token endpoint             | client authentication failure                                                                                                  | 401 `invalid_client`, no state change                                                                                                                                                                                                                                                                                                                             |
| OP token endpoint             | code unknown, expired, consumed or replayed                                                                                    | 400 `invalid_grant`, no state change for the victim flow                                                                                                                                                                                                                                                                                                          |
| OP token endpoint             | PKCE mismatch                                                                                                                  | 400 `invalid_grant`, no state change; the code stays usable by the holder of the verifier until expiry                                                                                                                                                                                                                                                            |
| OP token endpoint             | authenticated client and PKCE, but the signed expectation (section 6) or the bound grant, Identity or policy no longer matches | 400 `invalid_grant`; OP context to FAILED; no event, no rotation                                                                                                                                                                                                                                                                                                  |
| OP token endpoint             | token preparation or signing fails                                                                                             | 500 `server_error`, transaction rolled back, nothing committed                                                                                                                                                                                                                                                                                                    |
| OP token endpoint             | storage or outbox write fails                                                                                                  | 500 `server_error`, transaction rolled back, nothing issued                                                                                                                                                                                                                                                                                                       |
| RP exchange                   | network failure or timeout after dispatch                                                                                      | RP state to INDETERMINATE; the code is never resent; the owner starts a new step-up                                                                                                                                                                                                                                                                               |
| RP recovery                   | DISPATCHING older than the dispatch deadline (section 6)                                                                       | recovery writer moves it to INDETERMINATE with an outbox row; a late result cannot revive it                                                                                                                                                                                                                                                                      |
| RP installer                  | initiating generation superseded, session invalid or binding mismatch                                                          | RP state to REFUSED, credentials unchanged, operation not run                                                                                                                                                                                                                                                                                                     |

## 5. Evidence value and owner-side propagation

- `StepUpEvidence` is an immutable value object (`project/value-object-boundaries.mdc`: no writes,
  no OP calls). Only the shared verifier builds it from a payload already verified by the existing
  OP access-token verification (`OidcAccessTokenAuthenticator`, or the RP's
  `OidcOpAccessTokenVerifier` path). Fields: `acr`, `amr`, `auth_time`, `sid`, `sub`, `client_id`,
  `aud`, `jti`. The verifier checks issuer, audience and client, the exact class, the deadline
  against the database clock, and that `sid` and `sub` match the live session and actor. A browser
  or RP never supplies a boolean.
- In-process Base pages build it from `BrowserRpAuthentication::AccessState`. Owner APIs build it
  from the Access JWT they already verify after authenticating the calling self-RP with
  `private_key_jwt` (verified, `avatar_authority_api_endpoint.rb:7-11,26-40`); no new transport, no
  wider audience.
- Final writers take `step_up_evidence:` instead of reading the root token and recheck at the write
  boundary: deadline on the database clock, actor and session match, their own authorization. They
  no longer consume evidence; the 22 sites change together.
- `amr` is carried for attribution and audit only; per decision 7a no authorization decision reads
  it.

## 6. Intended grant, dispatch and completion

Intended grant (owner decision 2026-11-03, option 1; replaces the `id_token_hint` proposal of
revision 3).

- Fact: the `sid` in issued tokens is the per-client grant's public identifier (`usage.public_id`),
  not the OP root or device session (reviewer, `oidc_token_exchange_coordinator.rb:1023,1078`). The
  RP already stores it with `iss` and `sub` (verified, `rp_cell_local_session.rb:51-58`).
- At authorization the OP resolves the live grant of the requesting client under the active OP
  session, checks that the grant's parent device and root belong to that session, and binds
  `grant_id` and the subject into the OP context before any ceremony. No active session or no live
  grant: `login_required`.
- At the token exchange the RP already authenticates with `private_key_jwt`. For a step-up code its
  client assertion carries two additional claims, an owner-approved local extension that RFC 7523
  section 3 permits but does not standardize: `step_up_grant` (string, the session's stored `sid`,
  which is the grant public id) and `step_up_sub` (string, the stored `sub`). Signature, endpoint
  audience, client identity, expiry and `jti` replay rules stay as they are.
- RP builder: `OidcClientAssertionJwt.issue` gains a typed `step_up_expectation:` argument (a value
  object holding the two non-empty strings); today it issues only the standard claims (reviewer,
  `issue_with_configured_key`), and the RP token client builds its assertion internally (verified,
  `oidc_op_token_client.rb:65-66`), so that client gains the same typed argument. Ordinary sign-in
  and refresh pass none.
- OP verifier: one operation verifies the signature, endpoint audience, client, expiry and consumes
  the `jti`, and returns the authenticated client together with the validated expectation (or an
  explicit "none"). The existing boolean `valid?` / `OidcClientRegistry.authenticate_assertion` path
  keeps serving its current callers; the token coordinator's step-up branch uses the
  result-returning operation, so the JWT is never decoded again without authentication, no unsigned
  request parameter is read, and the single-use verifier runs once. The token coordinator replaces
  its initial boolean authentication call (`oidc_token_exchange_coordinator.rb:57,93-126`) with that
  operation and carries its result into code classification; both interfaces share one verification
  implementation.
- Rules: a step-up code (one with an OP context) requires both claims, non-empty strings, exactly
  equal to the bound grant's `public_id` and the bound subject; a missing, partial, wrongly typed or
  mismatched expectation is `invalid_grant` and FAILED, with no fallback to ordinary issuance or to
  OP-current selection. An ordinary code whose assertion carries either claim is `invalid_request`
  and gains nothing. Tests: missing, partial, wrong type, tampered, foreign client, wrong code
  purpose, replayed assertion.
- After commit the RP still compares the returned `sid` and `sub` with its session. No ID Token is
  stored, so sessions created before activation need no fresh sign-in (the earlier O-8 is
  withdrawn).

One dispatch, RP side:

1. Correlation, then the source-state check (section 4). Under a short transaction PENDING moves to
   DISPATCHING on the database clock; the transition row's `occurred_at` starts the dispatch
   deadline of 60 seconds (proposal, C-8). The deadline is an installation deadline, not only a
   recovery threshold. The lock is released before any network I/O.
2. The token exchange runs outside any transaction. A second callback finds DISPATCHING and
   gets 409.
3. Success: a new transaction installs (below). An OP error response: REFUSED. Network failure or
   timeout: INDETERMINATE. A worker that dies after committing DISPATCHING leaves the row to the
   recovery writer (`RpStepUpDispatchRecovery`), run by a recurring job every minute in the style of
   the existing recurring `op_outbox_dispatch` task, which moves DISPATCHING past the deadline to
   INDETERMINATE with an outbox row and never resends the code nor assumes the OP did not commit.
   Installer and recovery go through the same writer; the unique (`owner_id`, `to_state_id`)
   transition row lets exactly one of them win, and only the winner writes the outbox row. The fixed
   300 second proof window is unrelated to this deadline. Tests: just before, at and just after the
   deadline with recovery delayed; a late success after INDETERMINATE. The installer requires
   DISPATCHING, so a late result after recovery is refused. If the OP had committed, the event
   exists on the grant and a later refresh inside the deadline exposes it (AC-14).
4. Cancellation is allowed only from PENDING; logout during DISPATCHING makes installation refuse.

OP completion (point of no return), one transaction in the realm's OP database:

1. Authenticate the client, verify PKCE, the signed expectation and the bound context; failures
   follow section 4. DPoP (RV-97): the ordinary code path's `validate_dpop_proof` accepts an absent
   proof and does not compare an existing grant (reviewer,
   `oidc_token_exchange_coordinator.rb:1200-1212`), while the refresh path's
   `validate_refresh_dpop_proof` requires a proof for a bound grant and compares it with
   `usage.dpop_jkt` (`:220-221,352-367`). The step-up branch applies the refresh rule to the bound
   grant, under the issuance locks of step 2: if `dpop_jkt` is set, a valid, unreplayed proof whose
   key thumbprint equals it is required, otherwise `invalid_grant` with no event, no rotation and no
   digest change; the issued credentials keep `dpop_jkt`. The RP token adapter sends no DPoP header
   today (`oidc_op_token_client.rb:37-47,60-85`), so in-scope Base grants are expected to be
   unbound; the contract makes that an asserted invariant and refuses a bound grant before any
   mutation until the adapter can produce a proof. Ordinary sign-in keeps its own rule.
2. Take the issuance locks the refresh issuer already uses (`oidc_refresh_token_issuer.rb:89-107`),
   read the grant event as one snapshot on the database clock, prepare and sign the tokens inside
   the transaction.
3. Consume the code once, write the event, rotate the refresh token persisting the exact prepared
   credential digest, move the context to COMMITTED with its commit row, insert the outbox rows;
   commit. A signing or write failure rolls everything back.
4. Only after commit, send the prepared response. Prepared tokens never leave before commit. The
   sign-in guards stay: `create_or_resolve_active_usage!` rejects a non-retired grant for sign-in
   (`oidc_token_exchange_coordinator.rb:859-865`) and `RpCallbackCommitter` returns
   `already_enrolled` (`rp_callback_committer.rb:72`).

RP installation, one transaction in the RP database: lock the RP state; if it is not DISPATCHING,
stop with no new terminal fact (a late result for INSTALLED, REFUSED or INDETERMINATE never writes
again); then, on the database clock, if the dispatch deadline or the pending-flow `expires_at` has
passed, the installer itself moves the row to INDETERMINATE (with its outbox row) and installs
nothing, even when the recovery sweep has not run; otherwise recheck DISPATCHING, the live session,
the binding and the returned `sid` and `sub`; install under the existing generation protocol
(`rp_refresh_committer.rb:90-103`), refusing a superseded initiating generation; keep the DBSC
binding; move to INSTALLED; insert the RP outbox row; commit.

## 7. Data shapes and state machines (proposal; no migration is authorized)

NOT NULL everywhere; no column whose NULL means a state; terminal events are transition rows, not
nullable timestamps; one named writer per state machine; transitions recheck the owning database
clock; terminal states are absorbing (`generic/lifecycle-transition-writers.mdc`). Public
identifiers use `PublicId.generate`.

OP context, per realm (`client_step_up_contexts`, `operator_step_up_contexts`): `id` bigint PK;
`public_id` string(21) unique; `oidc_authorization_transaction_id` bigint unique FK; `grant_id`
bigint FK (the bound grant); `bound_subject` string(255); `requested_acr` string(255) check equals
the class; `state_id` bigint FK to `client_step_up_context_states`; `expires_at` timestamptz (the
transaction expiry); `lock_version`, `created_at`, `updated_at`. States: 10 PENDING, 20 COMMITTED,
90 CANCELLED, 91 EXPIRED, 92 FAILED. Edges: PENDING to COMMITTED (section 6); PENDING to CANCELLED
(`access_denied` from Auth); PENDING to EXPIRED (writer finds `expires_at` passed on the database
clock); PENDING to FAILED (an authenticated expectation, binding or policy mismatch, or an
unsatisfiable essential class). Unauthenticated or invalid requests never move it.

Retention of the OP context (owner amendment 2026-11-03, after Codex's unit 1 blocker): the context
and its transition rows are transient. Their FK to the authorization transaction is
`ON DELETE CASCADE`, so the existing `OidcAuthorizationTransactionPurger` (15 minute retention,
`oidc_authorization_transactionable.rb:21,32-34`) keeps working and no authorization request data
(state, nonce, PKCE) is retained longer than today.

OP commit facts (`client_step_up_commits`, `operator_step_up_commits`), durable and not linked to
the transient context: `id`; `grant_id` bigint FK to the realm's grants (grants are kept as history
and are not purged; their root FK is deliberately absent, `op_app_grant.rb`); `root_token_id` bigint
FK to `client_tokens` / `operator_tokens` `ON DELETE CASCADE`, so the fact lives exactly as long as
its root (roots are deleted by `RetentionPurgeJob`, `retention_purge_job.rb:233-253`); `context_ref`
string(21) unique, the context's `public_id` kept as an opaque correlation with no FK;
`verified_method` string(16) from the closed list `passkey`, `totp`, `email_otp`; `committed_at`
timestamptz; all NOT NULL. Written by the commit transaction; the authoritative method attribution
that the revocation owner reads by root across all its grants (section 9). A public test proves the
fact survives the authorization-transaction purge and disappears with its root.

RP state, per cell (`rp_step_up_states`, modeled on `rp_callback_states` without its nullable
`consumed_at`): `id`; `public_id` string(21) unique (the non-secret audit reference);
`rp_session_id` FK; `state_digest` string(64) unique; `browser_binding_digest`, `nonce_digest`
string(64); `pkce_challenge` string(128); `pkce_verifier_ciphertext` text; `issuer` string(255);
`realm` string(3); `client_id` string(64); `return_target` string(512), a validated same-RP relative
path; `initiating_generation` bigint; `state_id` FK to `rp_step_up_state_statuses`; `expires_at`;
`created_at`, `updated_at`. States: 10 PENDING, 15 DISPATCHING, 20 INSTALLED, 90 CANCELLED, 91
EXPIRED, 92 REFUSED, 93 INDETERMINATE. Edges: PENDING to DISPATCHING, CANCELLED, REFUSED or EXPIRED;
DISPATCHING to INSTALLED, REFUSED or INDETERMINATE (exchange failure or recovery).

Transition rows for both state machines: `..._transitions` with `owner_id`, `from_state_id`,
`to_state_id`, `reason_code` string(64), `occurred_at` timestamptz; unique (`owner_id`,
`to_state_id`). Writers: `ClientStepUpContextTransitionWriter`,
`OperatorStepUpContextTransitionWriter`, `RpStepUpStateTransitionWriter`, and the recovery entry
`RpStepUpDispatchRecovery` that uses the RP writer (operations).

Existing authorization states keep owning code issuance and redemption. The old `last_step_up_*`
columns and old ceremony tables stay for retained purposes until a separately approved removal. The
new tables are new, so their NOT NULL columns need no backfill.

## 8. Audit outbox (RV-85)

Pattern in the tree: `PasskeyAuditOutbox` writes a row inside the source transaction (refusing when
none is open) with a fresh `event_uuid`, a closed event-type list and sanitized metadata (verified,
`passkey_audit_outbox.rb:8-40`); `PasskeyAuditDeliveryJob` takes bounded batches, locks each row,
persists or finds the Chronicle record, compares identity, then acknowledges (verified,
`passkey_audit_delivery_job.rb:13-80`). Its nullable `acknowledged_at` and its hardcoded
`result: succeeded` (reviewer, l.93,115) are not copied.

Outbox, one per OP realm database and one per RP cell database (`client_step_up_audit_outboxes`,
`operator_step_up_audit_outboxes`, `rp_step_up_audit_outboxes`): `id`; `event_uuid` uuid unique;
`event_type` string(64) check in the closed list; `realm`, `client_id`; `subject_ref` string(255);
`context_ref` string(21) (the OP context or RP state `public_id`, never a state or browser secret);
`reason_code` string(64) from a closed list that includes `completed`; `payload` jsonb, schema per
event type, identifiers and reason codes only; `occurred_at` timestamptz; `delivery_state_id` FK (10
PENDING, 20 DELIVERED); `created_at`, `updated_at`. Rejected attempts are deduplicated by a partial
unique index on (`realm`, `client_id`, `context_ref`, `reason_code`)
`WHERE event_type = 'step_up.attempt_rejected'`; other events are unique only by `event_uuid`.

Delivery attempts: `..._audit_outbox_attempts` with `outbox_id`, `attempt_number` (assigned under
the outbox row lock), `attempted_at`, `outcome` (`delivered` or `failed`), `failure_code` string(64)
from a closed list including `none`; unique (`outbox_id`, `attempt_number`) and a partial unique
(`outbox_id`) `WHERE outcome = 'delivered'`.

Chronicle mapping per event, into the current result vocabulary only (`Chronicle::RESULTS` =
`intent`, `succeeded`, `failed`, `audit_incomplete`, `invalidated`, `manual_recovery_required`;
verified, `app/models/chronicle.rb:48`). The finer distinction stays in the action (= `event_type`),
the reason (= `reason_code`) and constrained metadata; the enum is not widened.

| Event                                    | Chronicle result | Reason examples                                                                                                    |
| ---------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------ |
| `step_up.requested`                      | `intent`         | `requested`                                                                                                        |
| `step_up.committed`, `step_up.installed` | `succeeded`      | `completed`                                                                                                        |
| `step_up.cancelled`                      | `failed`         | `user_cancelled`                                                                                                   |
| `step_up.expired`                        | `failed`         | `expired`                                                                                                          |
| `step_up.failed`                         | `failed`         | `binding_mismatch`, `expectation_mismatch`, `policy_refused`, `unsatisfiable_class`                                |
| `step_up.refused`                        | `failed`         | `op_error`, `generation_superseded`, `session_invalid`                                                             |
| `step_up.indeterminate`                  | `failed`         | `exchange_timeout`, `dispatch_deadline_passed` (the action records the uncertainty; no manual recovery is implied) |
| `step_up.attempt_rejected`               | `failed`         | `foreign_browser`, `state_mismatch`, `duplicate_callback`                                                          |

Closed code vocabularies for the new persistence and Chronicle records:

- Transition and outbox `reason_code`: `requested`, `dispatch_started` (the RP PENDING to
  DISPATCHING transition), `completed`, `user_cancelled`, `expired`, `binding_mismatch`,
  `expectation_mismatch`, `policy_refused`, `unsatisfiable_class`, `op_error`,
  `generation_superseded`, `session_invalid`, `exchange_timeout`, `dispatch_deadline_passed`,
  `foreign_browser`, `state_mismatch`, `duplicate_callback`. The OP's OAuth `access_denied` response
  is normalized to `user_cancelled`; raw protocol error strings are not retained.
- `step_up.failed` payload `failure_code`: `binding_mismatch`, `expectation_mismatch`,
  `policy_refused`, `unsatisfiable_class`.
- `step_up.refused` and `step_up.indeterminate` payload `failure_code`: `op_error`,
  `generation_superseded`, `session_invalid`, `exchange_timeout`, `dispatch_deadline_passed`.
- `step_up.attempt_rejected` payload `rejection_code`: `foreign_browser`, `state_mismatch`,
  `duplicate_callback`. An uncorrelated request with no known context reference does not create this
  event.
- Delivery-attempt `failure_code`: `none`, `chronicle_unavailable`, `retention_policy_missing`,
  `event_identity_conflict`, `chronicle_record_invalid`, `delivery_failed`. `none` is required for a
  `delivered` attempt. Exception text and request data are never stored as a code.

These lists are exhaustive. A writer rejects any other value, and the database checks the same sets.

Retention (RV-98), set explicitly in `ChronicleRecordPolicy::RETENTION_POLICY_BY_ACTION`, never
through its `security` fallback (verified, `chronicle_record_policy.rb:24-31,88-94`;
`auth.step_up.succeeded` and `auth.step_up.failed` are `compliance` today):

| Event                                                                                                | Retention    | Reason for the class                                    |
| ---------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------- |
| `step_up.committed`, `step_up.installed`                                                             | `compliance` | the authentication success, as `auth.step_up.succeeded` |
| `step_up.cancelled`, `step_up.expired`, `step_up.failed`, `step_up.refused`, `step_up.indeterminate` | `compliance` | the authentication outcome, as `auth.step_up.failed`    |
| `step_up.requested`                                                                                  | `security`   | a request observation, not an outcome                   |
| `step_up.attempt_rejected`                                                                           | `security`   | an abuse observation, as `auth.sign_in.failed`          |

Payloads (C-3), constrained per event, identifiers and closed codes only, never secrets, raw tokens,
state values, browser bindings, PKCE material or full request data:

| Event                                      | Payload keys                                                  |
| ------------------------------------------ | ------------------------------------------------------------- |
| `step_up.requested`                        | `rp_state_ref`, `return_target_kind`                          |
| `step_up.committed`                        | `op_context_ref`, `grant_ref`, `verified_method`, `auth_time` |
| `step_up.installed`                        | `rp_state_ref`, `grant_ref`, `installed_generation`           |
| `step_up.cancelled`, `step_up.expired`     | `op_context_ref` or `rp_state_ref`                            |
| `step_up.failed`                           | `op_context_ref`, `failure_code`                              |
| `step_up.refused`, `step_up.indeterminate` | `rp_state_ref`, `failure_code`                                |
| `step_up.attempt_rejected`                 | `context_ref`, `rejection_code`                               |

The result vocabulary question of C-3 is closed by the mapping above. Tests cover policy selection
and erasability through the public delivery boundary, and repeated delivery.

Delivery: `StepUpAuditDeliveryJob`, run after commit and from a recurring sweep so a lost enqueue
never loses a row; per row it locks, finds or creates the Chronicle record by `event_uuid`, compares
identity, writes the attempt row and moves the outbox row to DELIVERED. Concurrent workers serialize
on the row lock; a crash after the Chronicle write is recovered by the next run finding the record
by `event_uuid`. Before commit an outbox insert failure rolls back the transition; after commit
Chronicle outages only delay delivery. `ChronicleFallbackRecorder` stays diagnostic. Prerequisite:
the retention policy rows. The owner set `security` to 365 days on 2026-11-03; a Chronicle migration
inserts it as the `compliance` migration does (`ON CONFLICT (code) DO NOTHING`, no-op `down`), and
the existing `app_secret:provision_audit_policy` task keeps refusing a differing row. `ephemeral`
and `permanent` are not used by step-up and stay undecided.

## 9. Retained conditions, attribution and policy changes

- Existing enforcement revocation is preserved (RV-89, RV-95).
  `AuthenticationSessionRevoker.tokens_for_method` revokes, for a TOTP effect, every root whose own
  latest step-up was TOTP, with no grant-liveness condition (verified,
  `authentication_session_revoker.rb:28-42`; `adr/unified-enforcement.md` "Session revocation", set
  3, revokes in full). The new rule keeps that meaning at root level as a union, with no comparison
  between the two sources (owner decision 2026-11-03, revision 10, after Codex's unit 6 stop: the
  retained root columns are nullable, and ordering them against commit facts would give NULL a
  meaning; no backfill is allowed). Revoke a live root in full when either (a) its retained
  `last_step_up_method` equals `totp` (a value-equality predicate; no branch on whether the column
  is NULL, and `last_step_up_at` is not read), or (b) its latest OP commit fact by `committed_at`
  among those whose `root_token_id` is that root, whatever its grant's state, has `verified_method`
  `totp`. After activation ordinary step-up no longer writes the retained columns; the retained
  full-reauthentication committer keeps writing them and shared lifecycle revocation keeps clearing
  them, unchanged (correction in revision 11), so (a) covers pre-activation attribution and retained
  full-reauthentication. Accepted consequence: a root whose pre-activation step-up was TOTP and
  whose later step-up used another method is still revoked (over-revocation only, toward safety).
  Commit facts are kept for the root's lifetime so an expired or revoked source grant does not drop
  the attribution. Tests: (a) alone, (b) alone, both, neither; expired source grant with a surviving
  sibling grant; revoked source grant; a later different-method commit fact replacing an earlier
  TOTP fact within (b); several grants under one root. This is existing enforcement, not O-7.
- Policy change to accept explicitly (RV-92): `ClientPasskeyPolicy#management_credential` requires
  that the credential used for the last step-up is still accessible, using `last_step_up_method` and
  `last_step_up_credential_ref` (verified, `client_passkey_policy.rb:60-83`); it checks the
  authenticating credential, not the credential being managed. The new evidence carries no
  credential reference, so for ordinary step-up this requirement is removed. This is an intentional
  policy change that the owner's acceptance must include; other eligibility checks of the credential
  being managed are unaffected where they exist.
- Q-1 (owner decision, for now): the `ADVANCED` to `NORMAL` change accepts the ordinary step-up. At
  its commit the writer still checks the current `ADVANCED` mode and the current actor and session
  authority; a concurrently invalidated session or an expired event cannot authorize it. Revocation
  of every session and refresh token after the change is unchanged.
- `Client#configured_mfa_level_methods` (configured methods) and `AuthenticationBase`
  session-issuance attribution (l.2804-2810) keep the primary-login anchors independent of ordinary
  step-up.
- Full reauthentication keeps its dynamic checks (inventory section 5).

## 10. Verification mapping (extend, do not duplicate)

| AC          | Existing coverage to extend                                                                                                                                                    |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AC-2        | `test/controllers/base/oauth_freshness_e3_test.rb:23`                                                                                                                          |
| AC-6, AC-7  | `test/services/oidc/token_exchange_service_test.rb:329`; `test/operations/rp_refresh_committer_test.rb:54,65,183`; `test/operations/rp_refresh_logout_concurrency_test.rb:209` |
| AC-13       | `test/operations/rp_callback_committer_test.rb` (already-enrolled refusal)                                                                                                     |
| AC-17       | `test/operations/base_self_rp_credential_issuer_test.rb` (migrate or remove with a reason)                                                                                     |
| AC-9, AC-10 | `test/integration/step_up_required_response_shape_test.rb`; `gait/lib/request.test.ts`; `gait/controllers/passkey_ceremony.test.ts`                                            |

New public tests required: forged OIDC error and foreign browser leave the victim state unchanged;
bad client and bad PKCE leave the victim state unchanged; two simultaneous callbacks produce one
token dispatch; an error-bearing duplicate gets 409; crash before send and crash after response are
recovered to INDETERMINATE and a late success is refused; a mismatched signed expectation
(`step_up_grant`, `step_up_sub`), a switched OP Identity, a replaced root and another same-client
session produce no event or rotation on any grant; concurrent refresh or logout during token
preparation, and a signing failure, leave nothing committed or sent; committed outbox row with a
lost enqueue, Chronicle write followed by a lost acknowledgement, concurrent delivery jobs; the TOTP
enforcement effect revokes roots attributed through the OP commit fact; the `ADVANCED` to `NORMAL`
change is refused for an invalidated session or an expired event; CSRF failure for HTML and JSON on
the routed controller.

## 11. Routes and client registration

Class A routes only (`adr/rails-routing-resourceful-policy.md`); the current Base routes already
have this shape (`config/routes/base.rb:225-232`, `630-635`).

| Host               | Declaration                                                                             | Path                              | Purpose                                                                                        |
| ------------------ | --------------------------------------------------------------------------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------- |
| Base app, Base org | `resource :verification, only: %i(show create)`                                         | `GET`, `POST /verification`       | entry page; start                                                                              |
| Base app, Base org | `namespace :verification do namespace :oidc do resource :callback, only: :show end end` | `GET /verification/oidc/callback` | step-up redirect URI, separate from sign-in `/oidc/callback`                                   |
| Base app, Base org | `namespace :verification do resource :cancellation, only: :create end`                  | `POST /verification/cancellation` | cancel from PENDING                                                                            |
| Base app, Base org | `namespace :verification do resource :setup, only: %i(show create) end`                 | unchanged                         | retained bootstrap                                                                             |
| Base app, Base org | `namespace :verification do resource :completion ... end`                               | kept                              | still used by retained bootstrap and registration; only its ordinary step-up branch is removed |

No `acr` route. Registration: `OidcClientStoresStaticClientStore#build_redirect_uris` (verified,
l.120) adds `/verification/oidc/callback` as an exact URI for `base-app-ww` and `base-org-ww`.
`AuthBoundaryAuthorityMap. callback_path_for` returns the sign-in path unconditionally (verified,
`auth_boundary_authority_map.rb:124-125`); the step-up start selects its own registered URI
explicitly and leaves that method unchanged. `lib/runtime_role.rb` already covers the `verification`
prefix hierarchically (reviewer, l.103-109 and 154 onward); no new role.

## 12. Open points

- C-3 (closed): result vocabulary and payloads, section 8.
- C-4: ORG: same shapes in separate stores; ADVANCED passkey-only enforced at Auth and OP
  acceptance.
- C-5 (closed as a contract): DBSC binds the device session behind the root token. Its proof is
  checked on the existing device-session refresh path,
  `AuthenticationBase#device_session_refresh_allowed?` (verified,
  `authentication_base.rb:1841-1880`: a bound device session needs `Sec-Secure-Session-Id` or the
  DBSC session header plus the DBSC response, a matching session-id digest and
  `DbscVerificationService` with the token DBSC URL as audience). Step-up writes no field of the
  device session or its DBSC binding, and the RP grant's refresh-token rotation at the OP keeps the
  existing DPoP check of the OP refresh path. Test: a DBSC-bound session still needs a valid proof
  on its next device-session refresh after a step-up. Runtime browser behavior is unverified.
- C-8 (fixed as proposal): the RP pending state expires 15 minutes after start, equal to the OP
  authorization transaction lifetime (verified default `ttl: 15.minutes`,
  `oidc_authorization_transaction_coordinator.rb:21`); the dispatch and installation deadline is 60
  seconds after the DISPATCHING transition.
- O-7: whether a routine credential change closes an open step-up window (deferred). Existing
  enforcement revocation is not part of O-7 and stays mandatory (section 9).
- O-8: withdrawn; no ID Token is stored (section 6).

### Owner decisions pending design (revision 11, 2026-11-04)

- O-11 Auth and Base split (owner decision 2026-11-04; supersedes the scope of O-9 below). The split
  follows one rule: Auth keeps only what an external party binds to its URL, plus verification. Auth
  owns: sign-in and sign-up ceremonies; step-up verification for every method, reached only through
  the OP-mediated flow; the passkey registration ceremony (APP and ORG
  `verification/registration/passkey`), because WebAuthn binds the credential to the RP ID and
  origin; the social OAuth start and callback for sign-in, sign-up and link, and the link completion
  (APP Google and Apple, ORG Entra ID), because the providers register the callback URL and the
  state cookie must be on that host. Base owns, reading `StepUpEvidence` directly at its own write
  boundary with no handoff: social unlink and the social settings display (today Auth
  `settings/{google,apple}`, `settings/entra`, `disconnect_social_authentication`); TOTP
  registration and management (today Auth `settings/totps`, its enrollment and handoff); email and
  telephone registration (already Base); passkey rename and removal (already Base). The moved Auth
  endpoints are removed, not aliased. Auth APP and ORG keep no `/settings` index and no TOTP,
  display, rename, removal or unlink pages (owner decision 2026-11-04, refined the same day): Auth
  keeps only `settings/passkey` (APP and ORG passkey registration) and `settings/{google,apple}`
  (APP) for the provider link start (ORG Entra has no self-service link or unlink; owner retained
  `adr/org-entra-id-sign-in-boundary.md` on 2026-11-04, so ORG keeps no `settings/entra` on Auth),
  each with resourceful routes and each entered only with the O-9 admission. Everything else under
  settings is on Base. The Base to Auth handoff of O-9 is needed only for passkey registration and
  the social link start. Bootstrap (first authenticator) stays out of scope as decided on 2026-11-03
  unless the owner reopens it. This work is plan unit 6b; activation (unit 7) waits for it.
- O-9 Auth source writes (owner decision 2026-11-05; the latest direct owner instruction supersedes
  the earlier Base-passkey/Auth-social split). Auth is the source writer for APP and ORG passkey
  registration and APP Google/Apple social linking. Auth validates the Visa O-9 admission under the
  O-10 actor-first order, keeps the read-only OP authority transaction open through the Zenith
  mutation and durable receipt, and terminalizes the admission only after a fresh receipt read.
  Visa's OIDC callback reads the terminal result and does not authorize or repeat the source write.
  Base retrieves and displays the result; it does not write the credential or social link. The
  browser path is Base → Visa → Auth → Visa → Base. WebAuthn options and attestation verification
  remain on Auth's origin with the existing RP ID. Bootstrap `verification/registration/passkey` is
  unchanged and outside O-9. The existing `secret_digest` schema remains untouched; new Visa
  admissions use additive purpose-specific tables with no bearer secret. The old
  attach/confirm/redeem writers and their temporary endpoints/routes are removed; their tables
  remain inert schema. See `o9-visa-roundtrip-design.md` and the 2026-11-05 review in `zero.md`.
  Unit 7 remains gated on the required O-9 acceptance tests and the separate O-10
  registration-receipt gates.
- O-10 Cross-database gap. Section 5 requires a session invalidated concurrently to be refused, but
  migrated F1 writers and the Q-1 controller commit their principal-store (Zenith) mutation after
  the OP verifier transaction has committed. Owner decision: remove the gap by keeping the OP root,
  grant and device-session locks held until the principal-store write commits, not by accepting a
  residual window. This changes cross-database lock order and can deadlock with existing
  principal-to-OP security transitions, so it needs a design: the inventory of those transitions,
  one global lock order, and how a principal-store failure after the OP locks are held is handled.
  Codex proposes it; Claude Code reviews; the owner accepts.
- O-12 Base under the `shared` runtime role (owner decision 2026-11-04). The owner tested the flow
  in development and `POST /verification` returned 409 with no log and no message: development runs
  `UMAXICA_RUNTIME_ROLE=shared`, where `RpCellLocalSession#rp_cell_process?` is false and Base keeps
  the OP-chain session, while `RpStepUpStartIssuer` accepts only the RP cell session; the tests pass
  because they switch the role to an `rp-*` cell (`test/support/rp_cell_session_helper.rb`). The
  contract assumed Base always runs as an RP cell; that was an authoring gap. The owner keeps the
  `shared` role and chose option B: under `shared`, Base routes run the RP cell path (local RP
  session and RP access token), exactly as in an `rp-base-*` process, so the step-up flow works
  without a second evidence source. No OP-chain step-up path is added. The Base features that still
  depend on the OP root token (`current_session_token`) will fail under `shared` as they already do
  in an RP cell; they are listed and handled through O-9 and O-11, or reported. Independently, every
  `RpStepUpStartIssuer::Refused` and other refusal on the start and callback paths must log its
  reason code (no secrets) and show the user a localized message instead of an empty 409. Codex
  includes the `shared` change, its sign-in and session effects in development, and the list of
  exposed OP-root-token dependencies in the revision-13 draft.
