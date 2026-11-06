# DBSC Is Used Only for Authentication Refresh Tokens

## Status

Accepted (2026-11-05, owner decision).

## Context

Device Bound Session Credentials (DBSC) bind a browser session to a key held by the device (for
example a TPM), so a copied cookie cannot be refreshed on another device.

The repository has used DBSC in two places: the authentication sessions (Visa OP login sessions,
advertised by `AuthenticationBase#issue_dbsc_registration_header_for` at committed sign-in and at
refresh) and Preference (`preference_dbsc` and its refresh path). The Preference reassessment
(`adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md`, Proposed — Decision Deferred)
favors retiring Preference DBSC but did not decide it.

Preference values are display and consent settings, not authentication or authorization authority.
Binding them adds a second DBSC lifecycle, endpoint and failure path without protecting any
credential that grants access.

## Decision

DBSC is used only for the refresh tokens of the authentication and authorization system:

- the OP (Visa) login sessions, APP and ORG;
- the RP local sessions when they adopt DBSC (Base APP and ORG; tracked in
  `plans/backlog/visa-dbsc-registration-csrf.md`).

For those sessions, once a session is DBSC-bound, every refresh verifies the DBSC proof and a
failure refuses the refresh and revokes the session. Whether a session is bound is decided by its
recorded binding, never by the request.

Preference does not use DBSC. No Preference cookie, token or refresh path is bound by DBSC, and no
Preference surface advertises DBSC registration.

## Consequences

- Existing Preference DBSC code, cookies, columns and reference rows become retirement targets. This
  ADR decides the end state only; the removal, its migration and any data handling need their own
  reviewed change under the migration rules.
- The Preference reassessment ADR stays Proposed for its other questions; on DBSC it is resolved by
  this record.
- Statements in older ADRs that describe Preference DBSC as current
  (`adr/session-token-hardening-baseline.md`,
  `adr/preference-browser-transport-family-capability.md`,
  `adr/credential-response-nondisclosure.md`, `adr/preference-visa-writer-boundary.md`) describe the
  current code, not the intended end state, until the removal lands.
- `adr/device-session-dbsc-device-id-boundary.md` keeps its device-session vocabulary; this record
  narrows where DBSC applies.
