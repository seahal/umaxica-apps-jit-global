# Logout And Session Management

## Ownership

Visa owns OP authentication and authority-stop decisions independently for APP, COM and ORG. Base,
Core, Warp, Edit, Palm and Tech own their RP cookies, local sessions and return routes. A browser
cookie on one host never authorizes mutation of another surface's session.

`OpAuthorityStopCommitter` is the realm-specific writer that stops OP roots and grants. The durable
stop has root, grant, cutoff and BCL participant children. Sign-out is not a persisted sign-out-flow
lifecycle. Visa uses a one-use presentation notice for its own completion page; it creates no
browser receipt. A separate session marker distinguishes a repeat of a completed confirmation from
an unrelated stale submission and cannot authorize a stop.

## Current-device logout

The current OP session is the browser's Visa device session and its root-token rotation lineage.
Visa verifies an ID Token hint, when supplied, and binds its grant and client to that current device
before staging. A verified hint without an OP session or naming a grant from another device is
refused. An expired otherwise valid hint is accepted. Invalid HTML requests show localized generic
text; JSON responses retain protocol error details. An RP-cell request can omit the hint and supply
its registered client and exact return URI. Without a usable OP session this makes no authority
change; Visa returns to that URI with the request state, or reports already signed out when there is
no valid return. With a usable OP session, the normal device confirmation remains independent of RP
local sign-out.

The separate CSRF-protected confirmation rechecks the device and stops each root in its lineage, all
grants under it and the device itself. Each root stop records cause `rp_initiated_logout`, scope
`root` and no epoch cutoff. Other devices and realms stay independent. Sign-out-all and
revoke-other-sessions use their own explicit operations.

A failed pre-commit stop retains the Visa credentials and pending request. An unknown commit retains
them and returns 503 so retry can re-read the same device. After a confirmed commit, the browser is
cleared and the result remains signed out even if later notice storage or redirect construction
fails. Solid Queue and the recurring sweep deliver BCL after commit; delivery cannot undo the stop.

## RP completion

Before leaving the initiating RP cell, it stores a one-use completion notice bound to its surface
and OIDC `state`, commits local session revocation, and clears its own cookies. It then attempts RFC
7009 revocation of only the matching Refresh Token through the fixed Visa endpoint. A failure does
not restore local state and leaves the token subject to its original expiry. The return consumes
only the matching notice and refuses an active session or replay. If the person does not confirm at
Visa, the initiating browser remains signed out locally; the OP device and unrelated grants remain
active.

RP logout controllers use the local-session-first launcher and do not read or send a stored ID Token
hint. The separate shared-role `BrowserRpAuthentication` branch still reads the OP grant chain for
ordinary request authentication and refresh. This leaves the shared-role authentication surface
unreconciled under WU-A8; it is not a grant-hint branch in the logout launcher.

## Back-Channel Logout receiver

Each first-party RP receiver is bound to its registered issuer and client. It validates the Logout
Token, then commits replay receipt, absorbing `sid` tombstone and matching local grant revocation
before returning success. A request cannot choose another receiver's issuer, audience or surface.
The OP's durable participant is retried by Solid Queue and a recurring sweep after the stop commits.
HTTP 200 and 204 acknowledge delivery; other responses follow the retry or refusal policy. Discovery
advertises session-aware back-channel logout, and the ID Token and Logout Token use the grant public
ID as `sid`.

## Related contracts

- [Logout request and confirmation sequence](logout-sequence.md)
- [Visa OP and Base RP boundary](../../adr/visa-op-host.md)
- [Separated-store OP commit and BCL](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
- [Current sign-out acceptance requirements](../checklists/sign-out.md)
