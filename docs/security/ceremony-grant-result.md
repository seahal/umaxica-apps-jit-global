# Ceremony Grant And Result

> **Legacy Sign/Acme vocabulary:** The opening grant/result sections describe the retired
> `sign/id` → `acme/www` delegation model. They remain as historical context only. The current
> Rails browser OIDC contract is the Base/Auth contract in the section below; do not add a new
> signed or one-shot ceremony-result API based on the legacy wording.

## Purpose

Credential ceremonies delegated to `sign/id` must not smuggle session, account, token, preference,
or authorization mutations through redirects or provider state. They use an explicit grant/result
boundary.

## Historical Sign/Acme Ceremony Grant

`acme/www` issues the ceremony grant. The grant must be:

- short-lived;
- audience-bound to `sign/id`;
- purpose-bound to a single ceremony purpose;
- one-shot;
- bound to an acme transaction;
- bound to an acme session when the ceremony is session-scoped.

The grant authorizes ceremony execution only. It does not authorize `sign/id` to commit account,
session, preference, token, authorization, or freshness state.

## Historical Sign/Acme Ceremony Result

`sign/id` returns a signed ceremony result. The result must be:

- signed by `sign/id`;
- audience-bound to `acme/www`;
- purpose-bound to the original grant purpose;
- one-shot and replay-detectable;
- bound to the original acme transaction and session where applicable;
- expiring;
- limited to credential ceremony evidence.

`acme/www` validates and consumes the result once. Only acme commits any user session, refresh,
account, preference, downstream token, authorization, or step-up freshness change.

## Current Base/Auth browser OIDC transport

For the current Base/Auth browser OIDC flow, the Auth-to-Base result is never placed in a URL.
After a successful Auth ceremony:

1. Auth redirects the browser to a same-origin `GET /sign/oidc/handoff` page.
2. That page submits a CSRF-protected same-origin `POST /sign/oidc/handoff`.
3. Auth issues the short-lived opaque result and renders a form that submits it in the POST body
   to the matching Base `POST /oauth/authorize` endpoint.

The Base result endpoint accepts only the exact configured Auth origin (with the existing
same-site/null-origin proxy case), validates the result's digest/generation and transaction binding,
and verifies its surface binding before resuming the Base authorization transaction. The Valkey
result remains readable for its short TTL so a retried request does not lose a valid Auth result;
PostgreSQL row locking and `base_finalized_at` make Browser Session finalization idempotent. It
derives the single expected result purpose from that server-side transaction and does not probe
unrelated result-purpose namespaces. Rails forgery protection remains enabled; the cross-host form
does not share an Auth-host CSRF token and is protected by the exact origin boundary, result
generation/digest binding, and surface binding.

`GET /oauth/authorize?result=...` is not a result consumer. A result value in a GET request is
ignored by the result action and cannot consume or resume an authorization transaction. Auth
ceremony continuity remains in the surface-specific `AuthCeremonySession`; no Rails-session
pre-authentication map carries the result or RP transaction state. Base remains the authority for
the authorization transaction, Browser Session, RP Session, and authorization code.

## Redirects Are Not Results

Redirect targets, `rt`, `return_to`, OAuth `state`, and navigation parameters are navigation
mechanisms. They are not authentication or credential result transport. A redirect may carry the
browser to a result-resume endpoint, but the opaque transaction-bound result is the security object.

## Related

- `docs/security/redirect-vs-ceremony-result.md`
- `docs/security/credential-gateway.md`
