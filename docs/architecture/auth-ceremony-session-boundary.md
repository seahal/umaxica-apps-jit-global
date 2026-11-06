# Auth ceremony session boundary

Auth uses actor-specific `ClientAuthCeremonySession` and `OperatorAuthCeremonySession` rows in the
matching ticket DB. Each row has a NOT NULL `status_id` FK to its realm-local status reference; the
status is the current lifecycle authority, while admission, authentication, terminal, and SID
timestamps remain immutable event facts. COM authentication and its Visitor ceremony sessions have
been retired.

- Cookie `__Host-auth_sid` holds only a high-entropy random identifier.
- The database stores `sid_digest` (SHA-256), expiry, lifecycle status and event facts. An admitted
  record may carry the opaque `authorization_transaction_ref` correlation value plus `admitted_at`;
  this does not make Auth an authorization-transaction authority.
- Status IDs are 10 issued, 20 admitted, 30 evidence recorded, 40 replaced, 90 revoked, 91
  completed, 92 cancelled before authentication evidence, and 93 cancelled after evidence.
  `rotate_and_admit!` replaces a nonterminal predecessor and creates its admitted successor in one
  Ticket transaction. An already terminal predecessor keeps its state. Terminal rows cannot be
  admitted, rotated, completed, cancelled, or revived. Admission and terminal transitions lock the
  concrete row, and the database enforces one authorization transaction reference per actor-specific
  ticket database.
- Transition writers read the OP Base database clock after acquiring the ceremony row lock and write
  the state reference and event timestamp in the same transaction. Callers cannot supply a
  transition timestamp.
- Auth ceremony admission is never reconstructed from Rails-session intent, challenge, or admission
  keys. An APP social login attempt carries its initiating admitted ceremony row ID in Rails session
  only to correlate that provider callback: before consuming OAuth state, the callback requires the
  current host-only `auth_sid` to resolve to the same active ceremony. A mismatch is a no-write 409;
  the OAuth state remains unconsumed so the matching browser can continue. This correlation value
  cannot create admission, select an actor, or replace the current cookie-to-row lookup.
- The row must not carry identity, AAL, Base Browser Session, RP Session, role, or policy fields.
  Base admission remains authoritative via opaque handoff/result codes in
  `Valkey::AuthState::OpaqueAdmissionStore` (digest keys and CAS). The Base-to-Auth browser entry
  carries a short-lived non-secret reference in the initial GET. After browser binding confirmation,
  the current Auth entry GET consumes the admission through the reference index and rotates local
  continuity; the coordinator caps the continuation at 10 seconds. The index points to the
  digest-keyed record and never stores the raw code. The Auth entry and attachment require a GET
  with `Sec-Fetch-Mode: navigate` and `Sec-Fetch-Dest: document` before processing an admission
  reference; HEAD and requests without that pair are refused. A previously attached binding also
  requires the current host-only `auth_sid` to resolve to its exact active Auth continuity row
  before Auth redirects to Base/Visa confirmation or redeems the reference. A mismatch returns the
  shared 409 phase refusal before mutation; the final response boundary strips session/Auth cookies
  and DBSC headers. The same check protects direct `/ceremony_bindings` requests.
- Auth-state Valkey clients use a 250ms connect, read, and write timeout with zero reconnect
  attempts. The adapter issues one command attempt and does not add an application retry. The three
  socket budgets provide a configured 750ms upper bound for a Valkey operation while a PostgreSQL
  lock is held; this is a lock-hold budget, not an HTTP latency SLA. Timeout or other Valkey failure
  releases the database transaction and fails closed.
- After the parent and binding reach retention, the admission-binding collector may delete an
  expired Auth continuity row only after its last binding reference is deleted. Active statuses
  require expiry to pass retention; terminal statuses also require their terminal event to pass
  retention. It retains a row while any binding still references it.

See the integrated auth-boundary plan (P4) and `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

## Method-page Back navigation

APP Sign In Email, Passkey and Secret, APP Sign Up Email and Telephone, and ORG emergency Passkey
use the shared Page header's document-navigation link above the title. The controller supplies the
existing method-selection destination and the `actions.back` translation; Page renders the
decorative left arrow. The method-selection entry pages themselves have no added Back link. This is
navigation, not cancellation: it preserves all current phase/admission checks and does not
substitute browser history for the server-owned destination. Cancel remains a separate
CSRF-protected mutation.
