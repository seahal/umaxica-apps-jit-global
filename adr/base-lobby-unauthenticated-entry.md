# Base Lobby Unauthenticated Entry

## Status

Accepted (2026-09-11)

Amends `adr/logout-ceremony-boundary.md` for Base completion destination only.

## Context

Base local sign-out finished on `GET /sign/out/complete`. That page is a normal GET resource, so a
browser can open, reload, or bookmark it as if a sign-out had just happened. The intended contract
is Post/Redirect/Get: the mutation lives on `POST /sign/out`, and the next GET is the canonical
unauthenticated entry.

Base `/` already owns regional-host redirect and the existing unauthenticated landing. That
behavior stays. The missing named resource is a stable anonymous entry that authenticated actors
must not see.

Rails flash remains forbidden (`generic/no-flash-messages.mdc`). Sign-out already has a
session-bound, one-time marker in `SignOutNotice`. That marker is the transport for the one-shot
completion message.

Auth, Core, Side, and Palm keep their own `/sign/out/complete` pages. Those surfaces are relying
parties; their completion URLs stay surface-local.

## Decision

Base entry points are:

```text
GET /
  existing regional redirect and landing behavior

GET /lobby
  canonical unauthenticated entry
  anonymous -> 200
  authenticated -> redirect to /dashboard

GET /dashboard
  canonical authenticated entry
```

Base local sign-out is:

```text
POST /sign/out
  authentication and session cleanup
  reset_session
  issue SignOutNotice into the fresh session
  303 See Other -> GET /lobby?ri=...
```

`GET /lobby` consumes the notice. A later GET does not keep showing it. The lobby after a just
completed sign-out sets Inertia `clearHistory` so Back cannot restore a signed-in page.

`GET /sign/out/complete` is removed from Base app, com, and org. Base OIDC
`post_logout_redirect_uri` values for Base hosts, and Base logout-transaction completion URLs,
point at `/lobby`. Side hosts registered on `base-rails-rp` still complete at
`/sign/out/complete`.

GET is never a logout mutation.

## Consequences

- Anonymous Base visitors have a named entry that can receive a one-shot sign-out message.
- Authenticated visitors cannot stay on `/lobby`.
- `/` is unchanged.
- Rails flash is not reintroduced.
- Auth/Core/Side/Palm completion pages remain.

## Related

- `adr/logout-ceremony-boundary.md`
- `adr/logout-completion-boundary.md`
- `docs/security/logout-sequence.md`
- `.agents/harnesses/rules/generic/no-flash-messages.mdc`
