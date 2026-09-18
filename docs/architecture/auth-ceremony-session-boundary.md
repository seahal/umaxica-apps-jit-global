# Auth ceremony session boundary

Auth uses actor-specific `ClientAuthCeremonySession`, `VisitorAuthCeremonySession`, and
`OperatorAuthCeremonySession` rows in the matching ticket DB.

- Cookie `__Host-auth_sid` holds only a high-entropy random identifier.
- The database stores `sid_digest` (SHA-256), expiry, revoke/rotate timestamps.
- The row must not carry identity, AAL, Base Browser Session, RP Session, role, or policy fields.
  Base admission remains authoritative via opaque handoff/result codes in
  `Valkey::AuthState::OpaqueAdmissionStore` (60s TTL, digest keys, CAS).

See the integrated auth-boundary plan (P4) and `adr/base-auth-ceremony-and-seven-rp-boundary.md`.
