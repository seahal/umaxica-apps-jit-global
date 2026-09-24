# Redirects Versus Ceremony Results

> **Legacy Sign/Acme vocabulary:** References to signed, one-shot results from `sign/id` to
> `acme/www` below describe the superseded delegation model. For the current Rails browser OIDC
> flow, use the Base/Auth contract and PostgreSQL finalization authority documented in
> `docs/security/ceremony-grant-result.md`.

## Rule

Redirects move browsers. Ceremony results carry credential evidence.

Do not use redirect targets, `return_to`, `rt`, `pt`, `nt`, `xt`, OAuth `state`, OIDC `state`, or
provider callback navigation as proof that authentication, step-up, account linking, or sign-up
succeeded.

## Redirects

Redirect data may preserve safe navigation intent. It must be signed or registry-bound where the
existing redirect-target rules require it. It must not contain credential result facts.

## Historical Sign/Acme Ceremony Results

Ceremony results are signed security objects returned from `sign/id` to `acme/www`. They are
audience-bound, purpose-bound, one-shot, expiring, and transaction/session-bound where applicable.

`acme/www` consumes ceremony results and commits authority state.

## Current browser OIDC handoff

The current Base/Auth browser OIDC handoff follows the same rule. Auth does not put the result in a
redirect query or fragment. Its GET handoff only renders a same-origin CSRF-protected continuation
form; the following Auth POST creates the opaque one-shot result. A second form then submits that
result in the POST body to the matching Base `POST /oauth/authorize` endpoint.

The Base-to-Auth admission follows the same transport boundary. Base may carry only a non-secret,
short-lived transaction or local-entry reference in the initial Auth GET so that Auth can render its
same-origin continuation form. The admission code itself is never placed in that URL. The following
CSRF-protected POST consumes the reference atomically in Valkey, and then redirects to a clean
ceremony URL. A GET does not consume an admission, and the reference index stores only a pointer to
the digest-keyed admission record; it does not store the raw code.

Base accepts the result only from the exact configured Auth origin (including the existing
same-site/null-origin proxy case), checks the surface-bound result at atomic consumption, and then
resumes the pending Base transaction. `GET /oauth/authorize?result=...` never consumes a result.
Rails forgery protection is not disabled for this flow, and Auth ceremony continuity is stored in
the surface-specific database ceremony session rather than a Rails-session pre-authentication map.

## Related

- `docs/security/redirect_targets.md`
- `docs/security/ceremony-grant-result.md`
