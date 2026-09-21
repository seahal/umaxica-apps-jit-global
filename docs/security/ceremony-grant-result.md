# Ceremony Grant And Result

## Purpose

Credential ceremonies delegated to `sign/id` must not smuggle session, account, token, preference,
or authorization mutations through redirects or provider state. They use an explicit grant/result
boundary.

## Ceremony Grant

`acme/www` issues the ceremony grant. The grant must be:

- short-lived;
- audience-bound to `sign/id`;
- purpose-bound to a single ceremony purpose;
- one-shot;
- bound to an acme transaction;
- bound to an acme session when the ceremony is session-scoped.

The grant authorizes ceremony execution only. It does not authorize `sign/id` to commit account,
session, preference, token, authorization, or freshness state.

## Ceremony Result

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
3. Auth issues the one-shot opaque result and renders a form that submits it in the POST body to
   the matching Base `POST /oauth/authorize` endpoint.

The Base result endpoint accepts only the exact configured Auth origin (with the existing
same-site/null-origin proxy case), validates and consumes the result once, and verifies its surface
binding before resuming the Base authorization transaction. Rails forgery protection remains
enabled; the cross-host form does not share an Auth-host CSRF token and is protected by the exact
origin boundary, one-shot result consumption, and surface binding.

`GET /oauth/authorize?result=...` is not a result consumer. A result value in a GET request is
ignored by the result action and cannot consume or resume an authorization transaction. Auth
ceremony continuity remains in the surface-specific `AuthCeremonySession`; no Rails-session
pre-authentication map carries the result or RP transaction state. Base remains the authority for
the authorization transaction, Browser Session, RP Session, and authorization code.

## Redirects Are Not Results

Redirect targets, `rt`, `return_to`, OAuth `state`, and navigation parameters are navigation
mechanisms. They are not authentication or credential result transport. A redirect may carry the
browser to a result-consumption endpoint, but the signed ceremony result is the security object.

## Related

- `docs/security/redirect-vs-ceremony-result.md`
- `docs/security/credential-gateway.md`
