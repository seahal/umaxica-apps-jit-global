# Session And Token Authority

## Current Base/RP Authority (2026-09-20)

Base is the sole physical OIDC Identity Provider and Authorization Server. Base owns the Base
Browser Session and the surface-local RP Session beneath it. The seven first-party browser RPs
(`core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, and `edit-org`) receive
their Access and Refresh credentials from Base's token endpoint and store those credentials only in
host-only RP cookies on the RP host. A browser RP callback does not call the generic root
`log_in` path and does not create a second ClientToken, VisitorToken, or OperatorToken.

Auth owns credential ceremony continuity only. Auth does not act as an OIDC RP, exchange RP codes,
or issue Base Browser Session or RP Session authority. The RP Access JWT is validated locally at
the browser API boundary using the exact registered RP audience/client binding. Exchanged and
refreshed OIDC Access JWTs carry the RP Session identifier in the protocol `sid` claim and the
parent Base Browser Session public identifier in the private `umx_base_sid` claim. Normal bearer
validation uses the verified JWT claims, the active Base Browser Session binding, and the actor
resource; it does not perform an RP Session database lookup. Refresh, revoke, and logout remain
Base/RP-Session operations. Revoking only an RP Session therefore stops refresh and new issuance,
while an already-issued Access JWT remains usable until its natural expiry and verifier clock-skew
boundary.

The older `acme/www` and `sign/id` wording below is retained as migration history. It must not be
used to infer current physical ownership where it conflicts with the Base/Auth/RP boundary above.

> **Historical note:** The earlier Acme/Core/Sign component model is retained in the lower sections
> for migration traceability. The current physical authority is defined by
> `adr/base-auth-ceremony-and-seven-rp-boundary.md`: Base is the only IdP/Authorization Server,
> Auth is ceremony-only, and each first-party RP owns only its host-local credential transport.

## Historical Migration Authority

`acme/www` owns all user sessions, refresh token families, OAuth/OIDC token authority, access-token
issuance, downstream token issuance, session management, logout, revoke, compromise state, and
step-up freshness confirmation.

`sign/id` must not issue, refresh, rotate, revoke, list, or display user sessions. It must not issue
refresh tokens, access tokens, downstream tokens, or step-up freshness.

## Physical Storage

Logical authority moves now; physical DB movement is out of scope. Existing sign-side token tables,
models, services, or controller names do not imply sign-side authority. During migration they are
compatibility placement only unless a current ADR explicitly says otherwise.

## Downstream Trust

`core`, `line`, and future downstream services trust acme-issued downstream tokens only. They must
reject sign-issued session, access, and downstream tokens.

## Step-Up Freshness

`sign/id` may execute the credential ceremony for step-up. `acme/www` decides whether the signed
result satisfies the requested purpose and stores any resulting freshness on the acme session.

## Related

- `docs/security/logout-session-management.md`
- `docs/security/downstream-token-authority.md`
- `docs/security/step-up-ceremony-delegation.md`
