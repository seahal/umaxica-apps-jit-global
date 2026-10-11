# Logout Sequence

## Authority

Logout is acme/www session mutation.

`acme/www` owns current-session logout, all-session logout, session revoke, session-management UI,
refresh-token family mutation, device binding cleanup, step-up freshness cleanup, and logout audit.

`sign/id`, `core`, and `base` are relying parties. They may initiate logout and show local
ceremony/completion UI, but they must not revoke authoritative acme session state.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, or namespaces do not imply sign-side authority.

## User-Facing Ceremony

The browser ceremony is surface-local. Auth, Core, Side, and Palm use:

- `GET /sign/out/new`
- `GET /sign/out/edit`
- `POST /sign/out`
- `GET /sign/out/complete`

`GET /sign/out/new` is a redirect-only entry point. `GET /sign/out/edit` is the confirmation page.
`POST /sign/out` is the local logout action or RP launcher, depending on surface authority.
`GET /sign/out/complete` on those surfaces is the friendly completion page and is safe to reload.

Base app, com, and org no longer expose `/sign/out/complete`. Base local sign-out is PRG onto the
canonical unauthenticated entry:

- `POST /sign/out` performs local cleanup, stores a one-time `SignOutNotice`, and answers `303` to
  `GET /lobby`
- `GET /lobby` is the Base anonymous entry; authenticated actors are redirected to `/dashboard`
- the sign-out message is consumed on that GET and does not persist on later visits

See `adr/base-lobby-unauthenticated-entry.md`.

`/sign/out/edit?sot=` is retired from the normal browser flow. Completion is session-bound, not URL
token-bound.

## Unauthenticated Access Is Intentional — Do Not "Fix" It

This is a recurring misread, so it is recorded here on purpose: **the logout ceremony endpoints are
reachable without a signed-in session, and that is correct, not a vulnerability.** Do not add an
authentication requirement to these endpoints to "protect" them.

The safety comes from separating two concerns:

1. **Reachability** is `:open`. The browser logout controllers declare
   `declare_authentication_mode! :open` (e.g. `Sign::App::Sign::OutsController`). This only governs
   whether the _page_ can be rendered, not whether logout _logic_ runs.
2. **Execution** is guarded by the current session. The actual mutation path
   (`OidcRpLogoutLauncher#launch_oidc_rp_logout!`, and the Acme local-logout action) returns early
   with `current_resource.blank? || current_session_public_id.blank?` and only renders the
   completion page. No session is revoked, no token family is mutated, and no `id_token_hint` is
   minted when there is no session.

Therefore an unauthenticated visitor to `GET /sign/out/edit` sees only the static "already signed
out" branch (`sign_out_active_context_present?` is false), and an unauthenticated `POST /sign/out`
is a no-op that renders completion. There is nothing for an unauthenticated caller to "use" — the
feature has no effect without an authoritative session.

Reachability must stay open because authenticated-only routing would break legitimate flows:

- logout confirmation after the session has already expired (TTL lapse mid-flow);
- the OIDC end-session confirmation, where `/sign/out/edit` is shared with the Acme IdP and session
  state is not stable across the RP↔IdP round trip (see "Acme OIDC End-Session" below);
- idempotent revisits of Auth/Core/Side `/sign/out/complete` (reload, back button, bookmark), which
  must stay safe. Base has no completion GET; revisiting `/lobby` after the notice is consumed shows
  the ordinary anonymous entry.

Summary: **reachability = `:open`; execution = `current_resource` guard.** Both layers must remain.
Removing the guard would be the real bug; removing the openness would break expired-session and OIDC
logout flows.

## Acme Local Logout

Acme app/com/org surfaces own direct session mutation. Local logout:

1. resolves the current acme session;
2. revokes the current session and current token family with the existing logout primitive;
3. clears acme auth cookies and request-local actor state;
4. records logout audit through the existing authority path;
5. stores a one-time completion marker in the fresh session;
6. redirects to the same surface's `/sign/out/complete` (Auth/Core/Side) or Base `/lobby`.

Acme local logout must not self-redirect to `/oidc/logout` or mint `id_token_hint` for itself.

## RP Logout Launch

Sign/Core/Base browser surfaces are RPs. Their `POST /sign/out` actions:

1. capture the material needed for logout before any reset;
2. clear or reset the local RP session;
3. store an opaque state token in the fresh Rails session;
4. redirect to the corresponding Acme surface's `GET /oidc/logout`;
5. complete on the RP surface's `/sign/out/complete` after the Acme end-session flow returns, or on
   Base `/lobby` when the originating surface is Base.

The RP completion marker is session-bound and one-time. The browser may revisit completion safely,
but the server must not re-assert a fresh logout from stale state.

## Acme OIDC End-Session

`GET /oidc/logout` and `POST /oidc/logout` remain Acme-only protocol endpoints. They validate the
OIDC request, stage exact registered redirect URIs, and use the shared `/sign/out/edit` confirmation
when user confirmation is needed.

`post_logout_redirect_uri` must be an exact registry match. Invalid or unregistered values must
never be redirected to.

## Palm Contract

Palm remains a future native/app-link client. The future completion target is:

`https://<palm-host>/sign/out/complete`

This is documented only; runtime Palm logout is not implemented here.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/logout-session-management.md`
- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
