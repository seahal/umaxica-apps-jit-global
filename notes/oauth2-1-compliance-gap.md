> **INTERNAL ONLY — NOT FOR DISTRIBUTION** This document uses stale vocabulary (`sign.*` as AS) and
> is non-authoritative. Excluded from all vendor packages per decisions DEC-001/002 (pinwheel) and
> DEC-014 (vendor register).

# OAuth 2.1 Compliance Gap Note

Reference: draft-ietf-oauth-v2-1 (https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1)

## Purpose

This note captures the gap between the OAuth 2.1 draft and the current repository state, so that
Identity-engine implementation work can address the missing items explicitly. It complements
`notes/oidc-session-model.md`, which already records the overall design direction to "align
implementation with OAuth 2.1 direction".

This note is a design-direction document, not a statement that every part of the repository already
implements the model as described.

## Role Split Recap

- Identity provider (AS): `sign.*`, owned by the Identity engine
- Relying parties (RP): `acme`, `base`, `post`, and other future surfaces
- The authorization code + PKCE flow runs between RP and AS as defined in
  `notes/oidc-session-model.md`.

## Explicit Non-Use Declarations

The following OAuth 2.0 grant types are removed in OAuth 2.1 and MUST NOT be implemented in this
repository.

- Implicit grant (OAuth 2.1 §10.1). Tokens MUST NOT be returned directly from the authorization
  endpoint.
- Resource Owner Password Credentials (ROPC). The AS MUST NOT expose a password grant endpoint, and
  RPs MUST NOT collect end-user credentials to exchange for tokens.

These declarations are normative for this project. Any future proposal to re-introduce either grant
type must replace this note with an accepted ADR.

## redirect_uri Exact String Matching

OAuth 2.1 §2.3.1 requires the AS to reject authorization requests whose `redirect_uri` does not
exactly match a pre-registered value for the client. The check happens in two places, not only on
the front channel.

### Front-channel check (authorize endpoint)

- Endpoint: `/authorize` on `sign.*`
- HTTP method: GET (OAuth 2.1 §3.1 requires the authorization endpoint to support GET)
- Direction: Browser -> AS, with `redirect_uri` carried as a query parameter
- Rule: exact byte-for-byte match against the client's registered `redirect_uri` set.

### Back-channel check (token endpoint)

- Endpoint: `/token` on `sign.*`
- HTTP method: POST, server-to-server from RP to AS
- Rule: the `redirect_uri` sent with the code exchange MUST equal the `redirect_uri` used in the
  earlier authorize request. This prevents code substitution between different registered URIs of
  the same client.

### Loopback exception

OAuth 2.1 §2.3.1 permits the port component of loopback redirect URIs (`http://127.0.0.1/...` and
`http://[::1]/...`) to vary. This project's RPs are server-side web applications, so the default
position is to not enable the loopback exception. If a native or CLI client is added later, it
requires a separate design.

### Required work for this repository

- define where registered `redirect_uri` values live (AS side, Identity engine model)
- decide how client registration is authored (static config vs. managed table)
- add integration tests that reject unregistered, suffix-extended, and scheme-mismatched
  `redirect_uri` values on both endpoints
- keep the exact-match rule aligned with PKCE state/verifier handling described in
  `notes/oidc-session-model.md`.

## Open Gaps Against OAuth 2.1

Items below are known gaps or items that still need verification against current implementation.

| Requirement                                                  | OAuth 2.1 section         | Current status                                                                   |
| ------------------------------------------------------------ | ------------------------- | -------------------------------------------------------------------------------- |
| PKCE with S256 for all clients                               | §4.1.1, §7.5.1            | Design direction recorded. Implementation coverage should be re-verified per RP. |
| Authorization code single use                                | §7.5.2                    | Requires explicit test coverage.                                                 |
| Confidential client authentication required                  | §3.2.1                    | Related to #611 token endpoint hardening. Needs verification per client type.    |
| Refresh token rotation                                       | §4.3.3 (RFC 9700 §4.11.2) | Tracked in backlog #558.                                                         |
| Sender-constrained tokens (DPoP recommended)                 | §1.4.3                    | Tracked in backlog #573. See `docs/architecture/dpop.md`.                        |
| Refresh token bound to scope and resource                    | §3.2.3                    | Needs verification.                                                              |
| Bearer token MUST NOT be sent in query string                | §5.1.2                    | Needs repository audit of token transmission paths.                              |
| TLS for all protocol URLs except loopback                    | §1.5                      | Enforced at infrastructure layer.                                                |
| HTTP 307 MUST NOT be used for redirects carrying credentials | §7.5.3                    | Needs verification of current redirect codes on sign flows.                      |

## Relationship to Existing Plans and ADRs

- `notes/oidc-session-model.md` — overall OIDC and session direction
- `adr/oidc-authn-hardening-implementation-decisions.md` — OIDC hardening decisions
- `notes/gh611-harden-token-endpoints-csrf.md` — token endpoint hardening
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` — refresh and revoke hardening scope
  that owns AS responsibilities
- GH issue #558
- GH issue #610

## Status

Design-direction note. Intended to be superseded by per-item ADRs or implementation commits as the
Identity engine work proceeds.
