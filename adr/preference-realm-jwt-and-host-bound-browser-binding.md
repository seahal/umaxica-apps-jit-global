# Preference transport uses a realm JWT and a host-bound browser binding

## Status

Accepted on 2026-10-31 by the owner. This decision supersedes
[`preference-browser-transport-family-capability.md`](preference-browser-transport-family-capability.md)
for Preference credential scope and lifecycle. Its family-and-surface capability and endpoint
ownership decisions remain useful where they do not conflict with this ADR. The Preference
credential scope clauses in [`cookie-domain-scope-by-surface.md`](cookie-domain-scope-by-surface.md)
are also superseded.

## Decision

Each preference realm issues one signed Preference JWT on the `umaxica.<realm>` cookie domain and
two readable display cookies (`language` and `__Secure-experience`) from the same database snapshot.
Only that realm's Base and Visa surfaces hold the signing key and write Preference state. Other
hosts verify with the configured realm public key and never write, create a row, or issue or delete
the shared cookies.

The realm JWT uses ES384 with JOSE header `typ=JWT` and exactly seven claims: `iss`, `sub`, `aud`,
`iat`, `exp`, `jti`, and `preferences`. `sub` is the anonymous Preference row's public identifier;
`aud` is exactly `app`, `com`, or `org` for the corresponding realm. Each realm has an independent
keyring (`preference_app`, `preference_com`, or `preference_org`). The token lifetime is 400 days
from the successful database write. The former RFC 9068 Preference shape and generic
`PREFERENCE_JWT_*` issuer/key namespace have no compatibility reader.

Cookie consent and Web Push are gated by the Base host-only `__Host-preference_binding` cookie. Its
digest is stored with the anonymous row. A valid JWT without a matching active row and binding
record does not authorize consent or Web Push. The binding is not an authentication credential.

Preference display values are not authentication, authorization, presence, step-up, tenant
selection, or session proof. The JWT is not an authority for any of those decisions.

The shared JWT is `Secure`, `HttpOnly`, `SameSite=Lax`, and `Path=/`, with a realm-scoped `Domain`.
Readable display cookies use the same realm scope. Its lifetime starts at the database write time;
GET and HEAD do not extend it. Base may issue or delete the host-only browser-binding cookie; Visa
sign-out may rotate shared Preference state but does not issue, delete, or alter the binding cookie.

## Consequences

- The family capability registry decides whether a page renders preference controls. Interactive
  browser Preference controls are available on Base app, org, and com only; Auth, Core, and Warp
  render verified preference state read-only and their theme/consent PATCH endpoints refuse writes.
- Consent is proved by the host-only binding digest, not by a DOM cookie. Only Base reads or writes
  APP/ORG consent and Web Push state; other hosts report no consent decision and never enable Web
  Push.
- The realm-scoped cookie is delivered across that realm's hosts. No CORS or cross-origin fetch is
  introduced. Readers need the configured public key, issuer, audience, active key id, and rejected
  key ids.
- The JWT shape is a wire break. No compatibility reader is retained for the old shape.
