# Device Bound Session Credentials (DBSC)

> **Partially superseded by Identity Authority inversion:** The DBSC vocabulary in this document
> remains useful only where it does not assign session or token authority to `sign/id`. `acme/www`
> is the Session, Token, Account, Preference, Authorization, and downstream-token Authority.
> `sign/id` is ceremony-only. Existing sign-side physical tables/models do not imply sign-side
> authority.

## Preference registration advertisement

Preference DBSC registration is advertised only on hosts with a Preference DBSC endpoint.
Core app/com/org bases name their canonical `/api/v0/preferences/dbsc` path; Auth, Base and other
families without that endpoint do not advertise registration or issue an unused challenge.
Token DBSC routes do not substitute for Preference DBSC. Host-only credentials and existing
bound-credential validation remain unchanged. See
[response nondisclosure](../../adr/credential-response-nondisclosure.md).

## Specification

The DBSC implementation in this application is based on the W3C Web Application Security Working
Group specification:

- **W3C DBSC Specification**: <https://w3c.github.io/webappsec-dbsc/>

## Purpose

DBSC binds session cookies to a device-specific key pair. Even if a session cookie is stolen, it
cannot be used on a different device because the server requires proof-of-possession of the private
key that is bound to the session.

## Implementation

The server-side DBSC implementation lives in flat `app/services/dbsc_*.rb` files:

| File                                        | Purpose                                               |
| ------------------------------------------- | ----------------------------------------------------- |
| `app/services/dbsc_registration_service.rb` | Registers a device key pair and binds it to a session |
| `app/services/dbsc_verification_service.rb` | Verifies device proof-of-possession on requests       |
| `app/services/dbsc_record_adapter.rb`       | Persistence adapter for DBSC state                    |

Token tables (`user_tokens`, `staff_tokens`) store DBSC-related columns:

- `dbsc_public_key` (JSONB) — the device's public key
- `dbsc_challenge` — challenge value for registration
- `dbsc_session_id` — session binding identifier

## HTTP Header Boundary

The header syntax follows sections 9.1–9.4 of the
[W3C DBSC Editor's Draft](https://w3c.github.io/webappsec-dbsc/) inspected on 2026-10-22
(draft dated 2026-09-08), and [RFC 9651](https://www.rfc-editor.org/rfc/rfc9651.html).
This is a draft protocol; the checks below establish server behavior, not browser interoperability.

`DbscHeaderParser` accepts a quoted Structured Field String, decodes escaped quotes and
backslashes, and ignores syntactically valid item parameters. It rejects unquoted values,
malformed escapes, control characters, non-ASCII strings, lists and trailing input.
Controllers parse HTTP fields exactly once. The registration/verification services and
`DbscProofVerifier` receive decoded strings, not HTTP field syntax.

Both token and preference refresh endpoints compare the decoded identifier with the existing
record before issuing a challenge. A missing record returns 401, malformed identifier syntax
returns 400, and an unknown or unregistered identifier returns 403 without changing the challenge
or setting a cookie. `Sec-Secure-Session-Id` is preferred over existing alternate field names.
`DbscHeaderSerializer` quotes and escapes every registration/challenge string separately; the
challenge response uses the stored identifier. Valid challenge responses remain 403.

DBSC operational logs contain fixed event names and request paths, never session identifiers,
proofs, challenges or their prefixes. Proof `iat` values are type-checked and compared as numeric
epoch seconds before they can cause an out-of-range time conversion.

This header hardening does not change DBSC lifecycle states, persistence, controller ownership,
JWT algorithms or proof freshness policy. It does not establish conformance of the entire DBSC
implementation to every provision of the current draft.

## Relationship to DPoP

DBSC and DPoP (RFC 9449) serve similar purposes (proof-of-possession) but target different flows:

| Mechanism | Flow                                | Binding target                     |
| --------- | ----------------------------------- | ---------------------------------- |
| DBSC      | Browser cookie-based sessions       | Session cookie bound to device key |
| DPoP      | API access via Authorization header | Access token bound to client key   |

DBSC is the active browser-session binding mechanism. DPoP remains available for
Authorization-header token binding where an explicitly reviewed flow chooses it.

## VisitorAccount Token Strategy

See `docs/architecture/dpop.md` § VisitorAccount Token Strategy for the full matrix of token
transport and binding mechanisms across all client types (Rails HTML, Next.js, iOS / Android).

## Related

- `docs/architecture/dpop.md` — DPoP specification, implementation, and client token strategy
- `adr/engine-isolate-namespace-adoption.md` — engine architecture
- GitHub #731 — DPoP server-side support
- GitHub #733 — OIDC standard endpoints
