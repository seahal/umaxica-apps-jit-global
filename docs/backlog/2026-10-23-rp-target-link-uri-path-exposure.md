# RP return target path is readable outside the RP

Status: Deferred; recorded at the user's request on 2026-10-23. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Concern

The adopted design (owner decisions D-149 and D-151 of the 2026-10 authentication cycle) carries
the RP's internal return target as the `target_link_uri` claim of the RP's OIDC `state`, an ES384
JWS. A JWS is signed, not encrypted. The path is therefore readable wherever the `state` travels or
is stored: the authorization request URL sent to the OP, the OP's stored authorization transaction,
the Jump gateway and any log that records those URLs.

The design limits the value to a relative path with no query and no fragment, so query parameters
are never exposed. A path segment can still carry a value that should stay on the RP, for example a
protected page whose route contains an invitation code, a verification token or another
capability-like identifier. If such a page requires sign-in, its path, including that value,
reaches the OP and Jump.

The owner accepted this for the first implementation: the JWS approach is implemented as decided,
and a different mechanism is considered after it works.

## State when recorded

Not implemented. Today the RP still uses its earlier plain `pt` return path (`OidcSsoInitiator`,
`OidcCallback`). The JWS `state` and `target_link_uri` are defined in the cycle documents as Work
Unit WU-43 and have not been built.

## Options to evaluate when selected

- Accept only paths that Rails routing recognizes as a GET route of that RP and that contain no
  dynamic segment; anything else falls back to the RP default page.
- Keep dynamic segments but refuse an explicit list of routes whose segments are secrets.
- Keep the target on the RP (for example in the RP's pending entry keyed by the `state` `jti`) so
  the `state` carries no path at all, or encrypt the claim.

Each option needs boundary tests for accepted and refused paths, and an inventory of RP routes that
can be protected pages with secret-bearing segments.

## References

- [Redirect target lanes](../../adr/redirect-target-lanes-pt-nt-xt.md)
- [Signed return targets](../../adr/signed-return-targets-only.md)
- [Redirect targets](../security/redirect_targets.md)
