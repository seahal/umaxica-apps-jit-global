# Redirects Versus Ceremony Results

## Rule

Redirects move browsers. Ceremony results carry credential evidence.

Do not use redirect targets, `return_to`, `rt`, `pt`, `nt`, `xt`, OAuth `state`, OIDC `state`, or
provider callback navigation as proof that authentication, step-up, account linking, or sign-up
succeeded.

## Redirects

Redirect data may preserve safe navigation intent. It must be signed or registry-bound where the
existing redirect-target rules require it. It must not contain credential result facts.

## Ceremony Results

Ceremony results are signed security objects returned from `sign/id` to `acme/www`. They are
audience-bound, purpose-bound, one-shot, expiring, and transaction/session-bound where applicable.

`acme/www` consumes ceremony results and commits authority state.

## Current browser OIDC handoff

The current Base/Auth browser OIDC handoff follows the same rule. Auth does not put the result in a
redirect query or fragment. Its GET handoff only renders a same-origin CSRF-protected continuation
form; the following Auth POST creates the opaque one-shot result. A second form then submits that
result in the POST body to the matching Base `POST /oauth/authorize` endpoint.

Base accepts the result only from the exact configured Auth origin (including the existing
same-site/null-origin proxy case), checks the surface-bound result at atomic consumption, and then
resumes the pending Base transaction. `GET /oauth/authorize?result=...` never consumes a result.
Rails forgery protection is not disabled for this flow, and Auth ceremony continuity is stored in
the surface-specific database ceremony session rather than a Rails-session pre-authentication map.

## Related

- `docs/security/redirect_targets.md`
- `docs/security/ceremony-grant-result.md`
