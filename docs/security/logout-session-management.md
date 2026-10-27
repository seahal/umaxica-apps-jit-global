# Logout And Session Management

## Ownership

Visa owns OP authentication and authority-stop decisions independently for APP, COM and ORG. Base,
Core, Warp, Edit, Palm and Tech own their RP cookies, local sessions and return routes. A browser
cookie on one host never authorizes mutation of another surface's session.

`OpAuthorityStopCommitter` is the realm-specific writer that stops OP roots and grants. The durable
stop has root, grant, cutoff and BCL participant children. Sign-out is not a persisted sign-out-flow
lifecycle. Visa uses a one-use presentation notice for its own completion page; it creates no browser
receipt. A separate session marker distinguishes a repeat of a completed confirmation from an
unrelated stale submission and cannot authorize a stop.

## Current-device logout

The current OP session is the browser's Visa device session and its root-token rotation lineage.
Visa verifies a hint and binds its grant and client to that current device before staging. A verified
hint without an OP session or naming a grant from another device is refused. An expired otherwise
valid hint is accepted. Invalid HTML requests show a localized generic message; JSON responses retain
protocol error details. A no-hint request without an OP session reports already signed out.

The separate CSRF-protected confirmation rechecks the device and stops each root in its lineage,
all grants under it and the device itself. Each root stop records cause `rp_initiated_logout`, scope
`root` and no epoch cutoff. Other devices and realms stay independent. Sign-out-all and
revoke-other-sessions use their own explicit operations.

A failed pre-commit stop retains the Visa credentials and pending request. An unknown commit retains
them and returns 503 so retry can re-read the same device. After a confirmed commit, the browser is
cleared and the result remains signed out even if later notice storage or redirect construction
fails. Solid Queue and the recurring sweep deliver BCL after commit; delivery cannot undo the stop.

## RP completion

Before leaving the initiating RP, it stores a one-use completion notice bound to its surface and
OIDC `state`, clears its own cookies and resets its session. The shared RP path does not stop its OP
grant. The return consumes only the matching notice and refuses an active session or replay. If the
person does not confirm at Visa, the initiating browser remains signed out locally while the OP
device and its grants remain active.

## Back-Channel Logout receiver

Each first-party RP receiver is bound to its registered issuer and client. It validates the Logout
Token, then commits replay receipt, absorbing `sid` tombstone and matching local grant revocation
before returning success. A request cannot choose another receiver's issuer, audience or surface.
The OP's durable participant is retried by Solid Queue and a recurring sweep after the stop commits.
HTTP 200 and 204 acknowledge delivery; other responses follow the retry or refusal policy.
Discovery advertises session-aware back-channel logout, and the ID Token and Logout Token use the
grant public ID as `sid`.

## Related contracts

- [Logout request and confirmation sequence](logout-sequence.md)
- [Visa OP and Base RP boundary](../../adr/visa-op-host.md)
- [Separated-store OP commit and BCL](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
- [Current sign-out acceptance requirements](../checklists/sign-out.md)
