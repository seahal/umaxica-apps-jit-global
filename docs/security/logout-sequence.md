# Logout Sequence

This document describes the current first-party RP-Initiated Logout path under D-33. Visa is the
OpenID Provider (OP); Base, Core, Warp, Edit, Palm and Tech are relying-party (RP) surfaces. Each
surface owns its own host-only cookies, local session and completion route.

## RP initiation

1. The authenticated RP accepts `POST /sign/out` only while its RP grant is valid. It reads the
   verified ID Token stored with that grant and selects the exact registered
   `post_logout_redirect_uri` for the current host and region. A missing hint or callback leaves the
   grant and browser state unchanged and returns the RP's unavailable response.
2. The RP records a one-use completion notice bound to a random `state` and the RP surface, revokes
   its own grant, clears its own access and refresh cookies, resets its local Rails session, and then
   sends the browser to Visa's `end_session_endpoint` with `id_token_hint`, `client_id`, the exact
   callback URI and `state`.
3. The RP's own grant is already closed before navigation. If the person leaves the OP confirmation
   without confirming, the RP remains signed out while the OP Root Session and other RP grants stay
   active.

## OP request and confirmation

`GET` and `POST` to Visa's `/oidc/logout` are end-session requests. Visa verifies the ID Token
signature, issuer, audience, type and not-before time. An expired hint remains usable for logout.
When `client_id` is supplied it must match the verified token. The hint's subject must match the
authenticated OP actor. The hint's `sid` is not used: an RP ID Token identifies an RP grant, while
the current Visa session identifies the browser Root Session to stop.

The return URI must exactly match a URI registered for that client and realm. Visa stages the
request in the OP browser session and always presents its confirmation page. An absent OP session
or captured session identifier produces `login_required` without staging a request, redirecting to
the RP, or revoking anything. A subject mismatch is also refused before a mutation.

The user's confirmation is a separate CSRF-protected `POST /oidc/logout/confirmation`. It commits a
`rp_initiated_logout` authority stop for exactly the current Root Session. That stop revokes the
root and every RP grant under it; other device roots remain independent. After commit, Visa clears
its own credentials and redirects to the exact registered callback, adding the supplied `state`.
The redirect does not wait for asynchronous Back-Channel Logout delivery.

## RP completion and Back-Channel Logout

The RP completion route accepts only a live, one-use notice whose surface and `state` match the
browser return. It consumes the notice and renders completion; it does not create an
`AcmeLogoutTransaction` or revoke the RP grant a second time. Replayed, missing, mismatched or
expired state returns not found.

The OP stop transaction writes one durable Back-Channel Logout participant for each participating
grant. Solid Queue dispatch and the recurring sweep deliver Logout Tokens after commit. Each RP
receiver commits its replay receipt, `sid` tombstone and matching local-session revocation before it
answers success. Delivery does not decide whether the OP sign-out committed.

## Boundaries and evidence

`logout_challenge` belongs to OP-internal legacy confirmation paths; it is not an RP logout
parameter. The RP, Visa and each RP receiver retain separate ownership of their cookies, sessions,
routes and state. See [session management](logout-session-management.md),
[the OP host decision](../../adr/visa-op-host.md), and
[the separated-store logout decision](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md).

The 12-client RP launch/callback matrix and end-session request checks are local test evidence. They
do not establish production deployment or external RP delivery. Current WU-15/16/22 focused
verification is recorded in
[`evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md`](../../evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md).
