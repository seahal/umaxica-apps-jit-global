# Base and Warp Canonical Root Dashboard

## Status

Superseded (2026-09-28) by `adr/home-dashboard-authentication-boundary.md`. Previously superseded `adr/base-dashboard-return-navigation.md`.

## Context

Base and Warp each serve app, com, and org hosts. Before this decision the two families disagreed
about where the authenticated Dashboard lives:

- Base rendered the Dashboard at `/` for an authenticated request and also at `/dashboard`, so the
  same representation had two canonical URLs. Switcher, Avatar, Avatar ownership transfer,
  Preference, and the sign-out confirmation returned to `/dashboard`.
- Warp redirected an authenticated `/` to `/dashboard`, which alone rendered the Dashboard.

The requirement is one browser entry point per surface whose representation follows the server-side
authentication state.

## Decision

For Base and Warp app/com/org:

```text
GET /
  anonymous      -> Home
  authenticated  -> Dashboard

/ is the canonical browser entry point.
```

- The root controller selects the representation with the surface's existing `logged_in?`. The
  Dashboard branch keeps the Dashboard's existing guards: Base still requires the selected actor
  context and `authorize!` of the surface principal; Warp still runs `authorize!` of the surface
  principal, the same check its `DashboardsController` ran after `authenticate_*!`.
- Both representations send `Cache-Control: private, no-store`, because the same URL varies by
  credential and no shared cache may store either.
- `GET /dashboard` remains as a resourceful route and answers every request, anonymous or
  authenticated, with a 303 redirect to the same surface's `/` carrying only `ri`. It renders
  nothing. The route stays because Base nests `/dashboard/avatar_image` under it and existing links
  and bookmarks still reach it; removing it is a later decision.
- In-application return links (Switcher, Avatar, Avatar ownership transfer, Preference, sign-out
  confirmation Back link, Warp Dashboard and Settings links) point to the root helper.
- Sign-in already completes on `/` (`AuthenticationRedirects#sign_in_dashboard_path` for Base, the
  OIDC callback's default `pt` for Warp). Sign-out keeps its existing one-shot `/sign/out`
  completion page, whose Home link is `/`; with the session revoked, `/` renders Home.

## Alternatives Considered

### Keep `/dashboard` as the Dashboard URL and redirect `/` there

Rejected: it keeps two entry URLs and a redirect hop on every authenticated visit.

### Remove `/dashboard`

Deferred: Base nests the Avatar image resource under it, and existing links would 404.

### Redirect sign-out completion straight to `/`

Not adopted here: the `/sign/out` completion page carries the one-shot notice and history clearing
defined by the sign-out sequence; changing that flow is outside this decision.

## Consequences

- `/dashboard` is no longer canonical anywhere on Base or Warp; `PUBLIC_LEGACY_DASHBOARD` in
  `docs/security/public-entrypoints.md` records it as a redirect-only public entry.
- Warp `DashboardsController` is `:open` because it only redirects; it reads no actor state.
- Core and Edit dashboards are unaffected.
