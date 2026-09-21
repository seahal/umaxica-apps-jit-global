# Auth ceremony session boundary

Auth uses actor-specific `ClientAuthCeremonySession`, `VisitorAuthCeremonySession`, and
`OperatorAuthCeremonySession` rows in the matching ticket DB.

- Cookie `__Host-auth_sid` holds only a high-entropy random identifier.
- The database stores `sid_digest` (SHA-256), expiry, and lifecycle timestamps. An admitted
  record may carry the opaque `authorization_transaction_ref` correlation value plus
  `admitted_at`; this does not make Auth an authorization-transaction authority.
- A session transitions at most once to a terminal state: `revoked_at`, `completed_at`, or
  `cancelled_at`. Terminal rows cannot be admitted, rotated, completed, cancelled, or revived.
  Admission and terminal transitions lock the concrete row, and the database enforces one
  authorization transaction reference per actor-specific ticket database.
- Auth ceremony continuity is not reconstructed from Rails-session intent, challenge, or admission
  keys. The Rails session may still carry unrelated presentation and legacy flow state, but it is
  not authoritative for whether an Auth ceremony was admitted or which Base transaction it serves.
- The row must not carry identity, AAL, Base Browser Session, RP Session, role, or policy fields.
  Base admission remains authoritative via opaque handoff/result codes in
  `Valkey::AuthState::OpaqueAdmissionStore` (60s TTL, digest keys, CAS).
- Auth-state Valkey clients use a 250ms connect, read, and write timeout with zero reconnect
  attempts. The adapter issues one command attempt and does not add an application retry. The
  three socket budgets provide a configured 750ms upper bound for a Valkey operation while a
  PostgreSQL lock is held; this is a lock-hold budget, not an HTTP latency SLA. Timeout or other
  Valkey failure releases the database transaction and fails closed.

See the integrated auth-boundary plan (P4) and `adr/base-auth-ceremony-and-seven-rp-boundary.md`.
