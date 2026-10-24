# Redirects Versus Ceremony Results

> **Legacy Sign/Acme vocabulary:** References to signed, one-shot results from `sign/id` to
> `acme/www` below describe the superseded delegation model. For the current Rails browser OIDC
> flow, use the Auth/Visa contract and Visa authority documented in
> `docs/security/ceremony-grant-result.md` and `adr/visa-op-host.md`.

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

The current Visa/Auth browser OIDC handoff follows the same rule. Auth does not put the result in a
redirect query or fragment. After the user action, Auth redirects to a Design D GET continuation;
that navigation issues the opaque one-shot result and redirects to Visa with a non-secret result
reference. Visa's matching GET continuation validates the browser binding and consumes the result
atomically. The result itself is never a bearer value in the URL.

The Visa-to-Auth admission follows the same transport boundary. Visa may carry only a non-secret,
short-lived transaction or local-entry reference in the initial Auth GET. The admission code itself
is never placed in that URL. The Design D continuation GET verifies the host-only browser binding,
then consumes the reference atomically in Valkey and redirects to a clean ceremony URL. A GET is
allowed to consume only at this named continuation boundary; the reference index stores only a
pointer to the digest-keyed admission record and never the raw code.

Visa accepts the result only from the exact configured Auth origin (including the existing
same-site/null-origin proxy case), checks the surface-bound result at atomic consumption, and then
resumes the pending Visa transaction. The authorization endpoint itself never consumes a result; the
dedicated GET continuation owns that operation. Rails forgery protection is not disabled for user
actions, and Auth ceremony continuity is stored in the surface-specific database ceremony session
rather than a Rails-session pre-authentication map.

## Related

- `docs/security/redirect_targets.md`
- `docs/security/ceremony-grant-result.md`
