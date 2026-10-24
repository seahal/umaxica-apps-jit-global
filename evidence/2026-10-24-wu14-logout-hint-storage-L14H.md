# WU-14: RP-initiated logout ID Token hint storage

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.

Observed 2026-10-24 with the worktree already uncommitted. Unrelated WU-01/WU-05, security, schema,
test and documentation changes were preserved; no reset, clean, restore, deployment, production
credential mutation or external write was performed.

## Implemented

- Logout hints are stored in dedicated `op_{app,com,org}_grant_logout_hints` tables rather than a
  nullable grant column. Each row has a unique grant foreign key with `ON DELETE CASCADE` and a
  `NOT NULL` encrypted `id_token`; absence of a row means that no verified hint exists yet.
- The RP callback binds the latest verified ID Token to the matching grant under its lock. The
  logout launcher refuses without a stored hint and emits the registered Visa end-session request
  with `id_token_hint`, `client_id`, `post_logout_redirect_uri` and one-time state.
- Normal RP logout revokes the local RP session before redirect, clears RP continuity and does not
  perform an Acme/OP transaction in the normal path.
- Development and test migrations were run; all three OP structure dumps contain the new tables.

## Verification

- RP logout, callback binding, OP end-session and core/warp/tech sign-out surfaces: **215 runs,
  1,592 assertions, 0 failures, 0 errors**.
- The matrix covers registered RP redirects, binding partitions, truthful state, expired hints,
  CSRF/GET boundaries and the OP end-session controllers.

## Not covered by this slice

The full G-16 back-channel delivery/outbox scenarios remain outside WU-14. WU-15 and WU-16 are
explicitly excluded from this implementation request.
