# app Secret persistence shape proposal

This is a historical shape proposal. Its `consumed_at` removal discussion below
was superseded by the current receipt-confirmed retirement contract: Source
`consumed_at` records successful reconciliation only after durable canonical Ticket
commit evidence. The current schema and [rebuild ADR](../../adr/app-secret-phase1-rebuild.md)
govern implementation. Four operational lifetimes were accepted on 2026-10-05 UTC;
that decision grants no shared-database application or deployment authorization.

Direction approved and refined on 2026-10-03 (UTC). The current test runner
confirmed Client/Secret ownership at app_zenith and Token/SignInFlow at app_ticket.
The old app Secret data has no inheritance requirement. Approval below concerns
the concrete new issuance/receipt/outbox representation, not reconsideration of
that accepted destruction decision. The refined migrations have now been applied only to
task-owned disposable databases; application workflow integration remains incomplete.

## Before

```text
app_zenith.client_secret_credentials:
  user_id, user_identity_secret_status_id, user_secret_kind_id,
  secret_kind, usage_policy, uses_remaining, use_count, max_uses,
  safe_prefix, password_digest, lookup_digest, claimed_at, claim_operation_id, ...
app-only issuance with capacity reservation and audit source outbox: none identified
app_ticket: existing SignInFlow/Token and legacy Emergency operation
```

## Proposed after

```text
app_zenith.client_secret_credentials:
  id, public_id UNIQUE, client_id NOT NULL FK clients,
  issuance_id NOT NULL FK client_secret_issuances,
  name, password_digest, lookup_digest UNIQUE NOT NULL,
  confirmed_at, claimed_at, claim_operation_id,
  revoked_at, discard_at, purge_eligible_at,
  created_at, updated_at

app_zenith.client_secret_issuances:
  id, public_id UNIQUE, client_id NOT NULL FK clients,
  origin_operation_id, origin, attempt_number,
  browser_session_ref, sign_up_flow_ref,
  planned_count, expires_at,
  presented_at, confirmed_at, canceled_at,
  encrypted_payload, discard_at, purge_eligible_at,
  created_at, updated_at
  UNIQUE(origin_operation_id, attempt_number)

app_zenith.client_secret_audit_outboxes:
  id, event_id UNIQUE, event_name, client_ref, credential_ref,
  actor_type, actor_id, actor_public_ref, executor_job_id,
  operation_ref, occurred_at, reason, item_count,
  delivered_at, discard_at, purge_eligible_at, created_at, updated_at

app_ticket.client_secret_sign_in_receipts:
  id, operation_id UNIQUE, credential_ref UNIQUE, client_ref,
  sign_in_flow_id NOT NULL FK client_sign_in_flows,
  root_token_ref NOT NULL, committed_at NOT NULL,
  discard_at, purge_eligible_at, created_at, updated_at
```

Credential fields follow the accepted rebuild contract. The issuance FK identifies
the exact candidate batch. There is no credential kind/status replacement enum.
`origin` is an issuance fact with explicit manual/passkey-registration alternatives,
not a capability discriminator. `planned_count` is the immutable issuance decision
snapshot (0/1/2), not a second active-count authority. Manual permits 0/1 only.

Exactly one valid browser-session or sign-up-flow binding applies. References are
server-issued bindings, never user-selected authority. Expired/terminal issuance
does not reserve capacity. Reissue is a new explicit attempt after pending invalidation;
ordinary retry returns the existing attempt. A=20 omission keeps the result fact but
allocates no candidates, encrypted payload, or reserved count.

Source-generated event IDs and timestamps are facts. Audit columns are an explicit
allowlist, not arbitrary JSON. Nullable credential_ref allows issuance events; no
credential FK or delete cascade may erase outbox evidence.

### Independent credential and login facts

`claimed_at` records irreversible acceptance on Zenith. The success-only Ticket
receipt records canonical root-login commit; those can occur at different times,
and claim can exist without a receipt. `consumed_at` is removed: in this design it
would duplicate either claim or propagation of the Ticket success fact, without an
independent consumption operation. A reconciler retires the credential through
`discard_at` and retention after resolving its flow. Retirement is a distinct
physical-lifecycle fact, not restoration of eligibility. Audit can describe the
observed successful use by linking the immutable receipt operation; it must not
invent a second login time from the reconciler's clock.

Ticket receipt is not another session issuer. Its commit fields are written inside
the canonical root-login transaction. Cross-DB references have no fictitious FK;
the trusted flow, Client, credential, and canonical commit must be explicitly verified.
Only successful canonical commits create receipts, with committed_at and root_token_ref
required. There are no failure-attempt or pending receipt rows and no receipt terminal
columns. Failed, canceled, expired, and unknown outcomes remain authoritative on the
existing SignInFlow; terminal arbitration and delayed-commit exclusion use its lock.

### Issuance state derivation

Evaluate with a single writer DB timestamp T after obtaining the Client lock. Use
the following mutually exclusive order; no stored status or reservation enum is added:

| Predicate | Derived state | Reserves capacity |
| --- | --- | --- |
| planned_count = 0 | Omitted, terminal from creation | No |
| planned_count > 0 and confirmed_at is present | Confirmed, terminal | No |
| planned_count > 0 and canceled_at is present | Canceled, terminal | No |
| planned_count > 0, neither terminal fact present, expires_at <= T | Expired, terminal | No |
| planned_count > 0, neither terminal fact present, expires_at > T, presented_at is null | Pending presentation | planned_count |
| planned_count > 0, neither terminal fact present, expires_at > T, presented_at is present | Pending storage declaration | planned_count |

Reserving is a predicate on the two pending states, not a separate persisted state.
CHECK constraints prohibit both confirmed_at and canceled_at, prohibit confirmation
without presentation, and require presentation/confirmation before expires_at.
Omission rows have no expiry, presentation, confirmation, cancellation, or encrypted payload,
and no candidate rows. The expiry column bounds an issuance operation, not saved
Secret validity. An omission remains an omission without a deadline; ordinary
retries cannot reinterpret it as a new issuance. A presented pending batch may have
no encrypted payload because presentation removes that payload; confirmation is
bound to its fixed candidate set, not to the continued presence of plaintext.

Do not mark an expired issuance as user-canceled merely to clear a database index.
Client-row locking serializes all capacity operations and enforces at most one live
pending issuance; no partial unique index pretends that current time is immutable.

### Exact A and R rules

For the locked Client C and writer time T:

```text
A = COUNT credentials WHERE
    client_id = C.id AND confirmed_at IS NOT NULL
    AND claimed_at IS NULL AND claim_operation_id IS NULL
    AND revoked_at IS NULL AND discard_at > T

R = SUM issuance.planned_count WHERE
    client_id = C.id AND planned_count > 0
    AND confirmed_at IS NULL AND canceled_at IS NULL
    AND expires_at > T
```

DB constraints pair claimed_at with claim_operation_id and associate a candidate
with its Client and issuance. Confirmation commits the entire candidate set and
issuance fact in the same Zenith transaction, so capacity changes from R to A
without double counting. Issuance confirmation requires its reservation to remain
live at the newly read writer time; equality with expires_at is expired.

Candidates with confirmed_at null never contribute to A. Expired/canceled/omitted/
confirmed issuances never contribute to R, even with jobs stopped. Account suspension,
pending enrollment, selected context, and session state affect login authorization
separately; they do not free A. A/R are never supplied by the browser or replica and
are not persisted as derived counters. Claim removes a credential from A immediately;
retirement and physical deletion cannot release its capacity a second time.

Under Client lock validate A <= 20 and A + R <= 20 before and after each transition.
Any live different issuance conflicts before making a new allocation, even when
numerical headroom remains. Reusing the same authorized issuance returns its fixed
result and never adds a second reservation. Invalid inconsistent facts raise rather
than silently being reclassified as available capacity.

### Explicit audit actor attribution

The existing request identity is ActorValuesContext.subject with actor_type :client;
the persisted audit identity uses the existing Chronicle polymorphic convention
actor_type = "Client" and actor_id = that Client's id. Store actor_public_ref as
the Client public_id snapshot alongside the pair, so deletion cannot erase identity
explanation. These values come from the verified request actor, never client_ref,
request parameters, or the credential owner by default.

For an unauthenticated initial enrollment or an autonomous job, all three actor
columns are null; that is consistent with Chronicle's nullable actor representation.
Enrollment attribution uses operation_ref to its verified server-held sign-up flow.
Autonomous work additionally requires executor_job_id from the actual Active Job
execution. Do not fabricate a human actor or add a System principal model. A job
performing delayed work preserves the original event's actor; its execution identifier
does not replace the historical actor. CHECK constraints require the human actor
triple to be wholly present or wholly absent; app self-service permits only "Client".

### Audit vocabulary and source write boundary

The source outbox writer accepts only these facts:
`secret.created`, `secret.renamed`, `secret.claimed`, `secret.consumed`,
`secret.revoked`, `secret.discarded`, `secret.purged`, `secret.issuance_started`,
`secret.presented`, `secret.storage_declared`, `secret.issuance_omitted`, and
`secret.issuance_canceled`. Creation means storage-confirmed credential creation,
not merely candidate allocation. Consumption observes a canonical successful
receipt; its event time is the commit fact rather than a reconciliation time.
Logical retirement and physical deletion are separate events.

Reason codes are `capacity_full`, `passkey_registration`, `manual`,
`user_revocation`, `flow_expired`, `flow_canceled`, `login_committed`,
`payload_unavailable`, and `reissue`; absence is permitted when no reason is needed.
Free-form names and request parameters are not reasons. Item counts are integers
from zero through twenty or absent, with type verification before Rails coercion.

`ClientSecretAuditOutbox.record!` requires an already-open Zenith transaction,
preserves the supplied writer timestamp and operation reference, and mints an
independent event UUID. It does not enqueue or write Chronicle. Operation owners
must call it together with their state changes; the API is an audit recorder,
not authorization for the underlying operation. Historical event attribution is
readonly; delivery state can change independently. An anonymous context must
contain the existing canonical unauthenticated subject, not an authenticated
subject mislabeled as anonymous.

## Constraints and migration impact

### Delivery payload format pending approval

Before: no new app issuance delivery payload exists.

Proposed after, inside Rails authenticated encryption on the approved
`encrypted_payload` column:

```json
[["credential-public-ref-1", "synthetic-32-character-secret"],
 ["credential-public-ref-2", "synthetic-32-character-secret"]]
```

Each fixed tuple is `[credential_public_id, raw_secret]`. The example is illustrative
and contains no actual credential. The enclosing issuance row already owns Client,
operation, session/enrollment binding, count, and deadline, so those are not duplicated
inside each tuple. The exact tuple set must match the immutable database candidates.
One-item delivery contains one tuple; zero-item omission contains no payload, including
no encrypted empty array. This format is server-side only, never an Inertia prop or
browser-storage format. It cannot authorize presentation by itself.

Rails encryption reuses existing configured encryption keys and authenticated
encryption. No new secret key, custom cipher, or credential protocol is introduced.
The format requires explicit approval under the repository's data-shape gate before
implementing payload encoding/decoding. Reservation, old-schema reference retirement,
and other independent work need not wait for that approval.

- Enforce required references, unique public/lookup/event/operation identities,
  candidate ownership, coherent terminal facts, and nonnegative attempt/count values.
- Lock Client before issuance and credentials for capacity changes. Read writer DB
  time after lock; close expired reservations before attempting a new operation.
- Do not store derived A/R or plaintext in a browser identifier, audit field, or URL.
  Encrypted payload is transient server data and is removed after explicit presentation.
- Drop only the approved old app Secret tables/columns and legacy app-only state,
  after enumerating dependencies. Do not change com/org schema or shared constants.
- Write explicit Rails migrations and generated dumps; apply destructive rebuild only
  in a confirmed disposable DB. Old Secret data cannot be recovered by rollback.
- Duration settings, event vocabulary, and any receipt adjustment required by the
  actual canonical issuer remain separate reviewed details; no new arbitrary TTL is proposed.

The new persistence proposal is subject to
`.agents/harnesses/rules/generic/data-shape-design.mdc`. Application integration and
fresh-build verification are separate from the disposable legacy-schema rebuild.

## Durable claim-to-flow binding pending approval

Source inspection of ClientSignInFlow and AuthCeremonySession shows that the existing
local flow locator is the flow's 21-character public_id. It is not the UUID stored
in the new credential's claim_operation_id. Success receipts exist only after login;
therefore they cannot supply the missing correspondence after an interrupted claim.

```text
Before client_secret_credentials:
  claimed_at, claim_operation_id UUID UNIQUE
After client_secret_credentials:
  claimed_at, claim_operation_id UUID UNIQUE,
  claim_flow_ref VARCHAR(21) UNIQUE
  CHECK: claimed_at, claim_operation_id, claim_flow_ref are all NULL or all present
```

The operation UUID is generated by the server on irreversible acceptance. The flow
reference is taken only from the admitted, persisted app ClientSignInFlow after
checking its actor and existing browser/ceremony binding. It is an immutable binding
snapshot, not a client-supplied operation ID. Existing flow nonce/ceremony verification
continues to authorize browser continuation; the new reference grants no authority.
No raw nonce, cookie, or bearer is copied. No foreign key crosses Zenith and Ticket.

A dedicated additive migration would extend the approved rebuilt credential table.
Only task-owned disposable databases would receive it. The same-op reconciliation
would check this correspondence and the authoritative Ticket flow/receipt, while
never restoring eligibility or accepting a new Secret presentation. This proposal
is not implemented until explicit shape approval.

## Chronicle delivery shape pending approval

Chronicle already has a unique event_uuid and authoritative audit columns. Source
outbox actor and event columns are approved; the destination metadata projection
needs an explicit serialized-shape decision before implementing delivery.

```text
Before: none (no app Secret source-outbox delivery)
After chronicles:
  event_uuid = source.event_id
  action = source.event_name
  result = "succeeded"
  actor_type / actor_id = source actor snapshot
  occurred_at / reason = source occurrence facts
  metadata = {
    "client_ref": "nonsecret-client-ref",
    "credential_ref": "credential-reference",
    "operation_ref": "00000000-0000-4000-8000-000000000001",
    "actor_public_ref": "actor-reference",
    "executor_job_id": null,
    "item_count": 1
  }
  changeset = {}
```

Each metadata value comes from its corresponding typed source column; nullable
values remain JSON null. Actor numeric identity uses existing Chronicle columns;
public references retain explanation after credential deletion. No arbitrary JSON,
name, raw value, digest, Cookie or bearer enters the projection. The fields are
independent dimensions, so a positional tuple is inappropriate here.

The existing security retention policy supplies Chronicle retention through its
stored policy, without a new duration or a request-time find_or_create. Missing
policy remains an explicit error. Existing event_uuid uniqueness provides durable
deduplication. A conflicting existing UUID must fail rather than silently acknowledge
a different event. Zenith delivered_at is written only after matching Chronicle
persistence is confirmed; retries recover the destination-commit/source-ack gap.
No destination schema change, distributed transaction or compatibility path is
proposed. This projection remains unimplemented pending explicit approval.

## Registered Passkey provenance snapshot — proposed, not approved

Runtime inspection on 2026-10-04 confirms Client, ClientPasskey and Secret issuance
are on app Zenith. The old ClientPasskeyCeremonyTransaction is on app Ticket,
but current settings registration does not call that ceremony finalizer:
SignSettingsPasskeyRegistration starts no durable ceremony and saves the verified
Passkey directly. Its existence or a consumed-looking old row is not sufficient
evidence for Secret issuance. The signed-in confirmation slice currently tests
prepared issuance/presentation facts; it does not prove actual registration binding.

Before, relevant issuance fields:

```text
origin = 'passkey_registration'
origin_operation_id = server UUID
client_id = owning Client ID
browser_session_ref = owning root Token public_id
sign_up_flow_ref = NULL
planned_count = 2
```

After, the same fields plus:

```text
registered_passkey_ref VARCHAR(21) = verified, saved ClientPasskey.public_id
```

This is an immutable registration-origin snapshot, not another credential kind,
status or authentication proof. The creation coordinator derives it from the actual
server-verified, saved ClientPasskey and verifies ownership under the Client writer
lock. Browser parameters never select this reference. Registration persistence and
issuance/omission plus source audit must share that Zenith transaction. Current
operation-specific authorization still precedes registration and is rechecked at
presentation/confirmation; the new Passkey does not authorize its own registration.

Manual issuance keeps registered_passkey_ref NULL. Passkey-origin issuance,
including planned_count=0 omission, requires a nonempty reference of at most 21
characters, matching the existing PublicId limit. Proposed uniqueness on
(registered_passkey_ref, attempt_number), excluding NULL, prevents another origin
operation UUID from creating a second same-attempt batch for the same registration.
Reissue uses the same origin operation and an explicitly advanced attempt after
invalidating its pending predecessor. A confirmed or omitted registration result
cannot trigger a later new issuance; its terminal source facts remain authoritative.

The snapshot has no deletion cascade or cross-DB foreign key. Subsequent removal
of the originating Passkey does not revoke confirmed Secrets or erase their origin.
Before the snapshot is written, the coordinator validates the concrete owned
ClientPasskey in the same database. Initial signup additionally binds the pending
Client, verified signup flow and registration result; it cannot use signed-in
bootstrap or this snapshot as a replacement for signup authorization.

After approval, add the column and constraints through a new app Zenith migration,
update structure and fixtures, and verify fresh construction and disposable upgrade.
Do not rewrite an applied migration to make it appear current. Existing disposable
Passkey-origin trial rows without provenance must be explicitly retired or rebuilt;
do not fabricate a parent reference or infer it from account credential counts.
There is no deployed-data compatibility requirement and no proposed API field here.
Rollback cannot reconstruct removed provenance; shared/production application
remains outside this task's destructive-DDL authorization.

This proposal does not revive the old signed Passkey ceremony framework or settle
the separate encrypted delivery tuple, claim-flow reference or Chronicle projection
proposals above. Full registration retry/response-loss behavior still requires
integration tests through actual registration and the bound operation locator.
# Revised replay-protection proposal (approval pending, 2026-10-05 UTC)

The admitted manual HTTP journey now reproduces an additional allocation when
the original create POST is resent after storage confirmation. Confirmation
currently removes the session's operation locator, allowing create to select a
new UUID. Fixing this requires identifying the submitted operation, rather than
interpreting every later POST as a new request. This revision supersedes the
earlier outbox-only approval question; no implementation shape has changed yet.

```text
Manual form before: {authenticity_token}
Manual form after:  {authenticity_token, operation_id: server_uuid}

Rails session before: {client_secret_operation_id: server_uuid}
Rails session after:  {client_secret_operation: {id: server_uuid, session_ref: current_token.public_id}}

Outbox before: operation_ref, client_ref
Outbox after:  operation_ref, client_ref,
               issuance_origin,
               issuance_browser_session_ref,
               issuance_sign_up_flow_ref
```

The operation UUID is server-generated, nonsecret and submitted in a hidden
field. The controller compares it with the operation bound to the current root
session before reservation. Existing scoped Step-Up, expiry and ownership still
apply. An explicit new form can prepare a new nonsecret operation; GET never
creates a reservation, candidate, grant, challenge or Step-Up state. Old forms
cannot select a newer operation. Confirmation preserves enough locator state
for ordinary retransmission to return the existing result; a different session
cannot use an old browser locator. Legacy locator shapes are refused rather than
read through a compatibility fallback.

Named session fields are intentional: explicit operation/session references
reduce the risk of reversing authentication bindings compared with positional
values. They are authority bindings, not a new proof of Step-Up.

The three Source outbox snapshots come from the locked issuance immediately
before deletion. `issuance_origin` reuses manual/passkey_registration; exactly
one session/signup reference accompanies a snapshot. They establish which
original authority must be terminal before its replay barrier can retire.
Unknown authority remains retained. The model's existing Chronicle allowlist
does not include these Source-only snapshots; Chronicle payload is unchanged.

The revision affects app form props/request data, app Rails session serialization
and an app-only additive migration. No plaintext, digest or authentication cookie
is stored in the new fields. It does not change accepted TTL values, com/org,
or authorize shared database application. Production-shape changes await explicit
approval under the data-shape harness; the failing HTTP test remains evidence of
the uncorrected behavior.
