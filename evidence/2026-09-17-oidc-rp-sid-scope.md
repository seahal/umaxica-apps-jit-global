# OIDC RP Session Logout Identifier Scope

- Date: 2026-09-17
- Branch: `feature`
- Previous committed slice: `6a8a3c22a`
- Scope: make back-channel logout compatible with the repository's RP Session identifiers and bind
  the revoke target to the verified client audience.

## Findings and change

RP Sessions use URL-safe Nanoid `public_id` values, while legacy Base Browser Session OIDC bindings
use UUID `oidc_sid` values. The logout codec and receiver previously accepted only UUIDs, so an RP
Session `sid` could not reach the RP Session row. The codec now accepts a bounded URL-safe opaque
`sid`; the receiver still rejects blank, malformed, and oversized values.

The receiver passes its fixed registered client ID into `OidcRpSessionLogout`. The operation queries
only the fixed surface writing connection, matches the RP Session and client first, and only then
considers the legacy parent binding. It passes the concrete matched record class to the existing
logout primitive. The legacy UUID-shaped lookup is guarded before querying the PostgreSQL UUID
column, so a Nanoid cannot be sent to a UUID cast.

## Commands and results

- `ruby -c` on the changed Ruby sources and tests — passed.
- `bundle exec rubocop` on the six changed source/test files — passed; 6 files inspected, no
  offenses.
- `git diff --check` — passed.
- The focused Rails test command for the codec, RP-session logout, and receiver tests was attempted
  with isolated Valkey environment variables but was blocked before test execution because
  PostgreSQL host `primary` could not be resolved.
- `pg_isready -h 127.0.0.1 -p 5432` — no response.

Database-dependent assertions for Nanoid logout, client binding, child-only revocation, and legacy
parent compatibility remain unverified until the repository's isolated PostgreSQL test service is
available. No shared or non-test database was used.
