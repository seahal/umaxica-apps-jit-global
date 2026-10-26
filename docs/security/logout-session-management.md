# Logout And Session Management

## Ownership

Visa owns OP authentication and authority-stop decisions for APP, COM and ORG. Base, Core, Warp,
Edit, Palm and Tech own their RP grants, cookies, local Rails sessions and return routes. A browser
cookie on one host never authorizes that host to mutate another surface's session.

The realm-specific `OpAuthorityStopCommitter` is the only writer that stops an OP root or grant.
`op_*_authority_stops` are the durable authority records; root, grant, cutoff, participant and
browser-receipt rows are their typed children. Sign-out is not a persisted `ClientSignOutFlow`,
`VisitorSignOutFlow` or `OperatorSignOutFlow` lifecycle.

## Current-session logout

Visa's normal sign-out action establishes that the current browser session owns the root it asks to
stop. The authority-stop transaction revokes that root and all RP grants under it. It does not stop
other roots for the same person. “Sign out all sessions” and revoke-other-sessions use their own
explicit operations and scopes; they do not widen a current-session logout.

For RP-Initiated Logout, D-33 requires the same OP confirmation boundary. The RP first revokes its
own grant and clears its host-only credentials. Visa validates the stored ID Token hint and exact
registered return URI, but neither the hint nor its `sid` is authority. Visa matches the hint subject
to the signed-in OP actor and uses the current OP session's Root Session ID as the stop target. The
hint may be expired; its signature, issuer, audience, token type and not-before claims remain
verified. A missing OP session or captured session ID fails with `login_required` without a staged
request, redirect or mutation. See [the logout sequence](logout-sequence.md).

The confirmation is a separate CSRF-protected POST. An accepted confirmation records cause
`rp_initiated_logout`, scope `root`, and no epoch cutoff. It revokes the root and its grants in the
OP authority transaction, records BCL participants for participating grants, and redirects after
commit. Solid Queue sends BCL asynchronously. A BCL delivery error cannot undo an OP stop or cause a
new login.

## RP completion

Before leaving the initiating RP, the RP stores a one-use completion notice bound to its surface and
the OIDC `state`, revokes its grant, clears its own cookies, and resets its local session. The
callback consumes only the matching notice. It performs no second grant revocation and does not use
`AcmeLogoutTransaction` for this OIDC path. If the person does not confirm at Visa, only the
initiating RP remains signed out.

## Back-Channel Logout receiver

Each first-party RP receiver is bound to its registered issuer and client. It validates the Logout
Token, then commits replay receipt, absorbing `sid` tombstone and matching local grant revocation
before returning success. A request cannot choose the receiver's issuer, audience, callback URI or
other RP surface. The OP's durable participant is retried by Solid Queue and a recurring sweep;
delivery runs after the stop commit and outside authority locks.

## Related contracts

- [Logout request and confirmation sequence](logout-sequence.md)
- [OP authority-stop scope table](../../two.md#58-wu-16--wu-22--op-authority-stop-record-accepted-design-locally-implemented)
- [Visa OP and Base RP boundary](../../adr/visa-op-host.md)
- [Separated-store OP commit and BCL](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
- [Current sign-out acceptance requirements](../checklists/sign-out.md)
