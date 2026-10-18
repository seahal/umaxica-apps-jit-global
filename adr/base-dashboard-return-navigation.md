# Base Dashboard Return Navigation

> **Supersession (2026-09-28):** `/` is the canonical Dashboard entry on Base and Warp app/com/org;
> `/dashboard` only redirects to `/`. See `adr/base-warp-canonical-root-dashboard.md`.

## Status

Superseded (2026-09-28) by `adr/base-warp-canonical-root-dashboard.md`; accepted 2026-09-24

## Date

2026-09-24

## Context

Base app, com, and org currently render the authenticated Dashboard from each surface's root path.
The signed-out confirmation and Preference pages need a stable return destination that does not use
browser history or the Referer header. An earlier authentication-boundary decision removed
`/dashboard` routes across Auth and Base; the current requirement adds that path only to Base.

## Decision

- Add a singular resource `GET /dashboard` route on each Base app/com/org host and use the generated
  surface-local route helper.
- Each surface's `RootsController#show` serves its named Dashboard route, using that surface's
  authentication state and the existing selected-actor, authorization, and rendering behavior.
- An unauthenticated Dashboard request returns to that surface's `/` route. The existing root
  landing and authenticated Dashboard behavior remain unchanged.
- Base `/sign/out/edit` provides a plain route link to the same surface's named Dashboard. Its Logout
  form continues to submit the existing sign-out mutation.
- Base `/preference` returns an authenticated request to the named Dashboard and an unauthenticated
  request to `/`, using the existing server-side authentication state. Preference writes remain
  separate from navigation.
- Auth, Core, Warp, and Palm route behavior is unchanged by this Base-only addition.

## Alternatives Considered

### Keep the root as the only Dashboard destination

Rejected because the required return contract names `/dashboard` and requires a named route helper.

### Redirect `/dashboard` to `/`

Rejected because it would not provide a distinct named destination for the Dashboard return links.

### Use browser history or Referer

Rejected because neither identifies an authoritative same-surface destination and both can cross
an unintended navigation boundary.

## Consequences

- Base gains a public path; this is the requested additive path contract. Existing paths and host
  routing remain unchanged.
- Auth and RP surfaces continue to treat `/dashboard` as retired.
- Return navigation is server-generated and does not choose or mutate the selected Persona.
- Avatar image delivery remains governed by the existing storage boundary; this decision does not
  establish a public URL or expose private object storage.

## Current naming note

This ADR was accepted while the Rails RP surface was named Side. The current Rails namespace is
Warp; the public host, URL, OIDC, and persisted contracts were not renamed.
