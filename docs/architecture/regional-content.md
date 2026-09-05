# Regional And Global Delivery Boundary

> **Partially superseded by Identity Authority inversion:** The old RP vocabulary in this document
> must not be used to treat `acme/www` as an RP-only boundary. `acme/www` is now the Session, Token,
> Account, Preference, Authorization, and downstream-token Authority. `core`, `line`, and future
> downstream services trust acme-issued downstream tokens.

## Status

Regional RP delivery remains outside this repository's stable application architecture. Per
`adr/split-into-regional-and-global-repos.md`, regional RP delivery belongs to the separate regional
repository.

> **Content surfaces re-scoped (2026-07-16):** Per `adr/publishing-db-content-authority.md`, `info`,
> `docs`, `news`, and `help` are now all **global content surfaces**. Their content authority lives
> in the central `publishing` database in this Rails repository, not in a regional repository or
> per-surface zenith databases. `app`/`com`/`org` are audience identifiers, not database placement.
> The regional rows for `docs`/`news`/`help` in the boundary map below are historical.

Read-only `docs`, `news`, and `help` content delivery in Rails was first accepted by
`adr/read-only-content-surfaces-in-rails.md` (now superseded). The Rails implementation is public
and read-only; it does not restore the old regional engine, OIDC RP callbacks, preference writes, or
authenticated actor lifecycle.

## Boundary Map

| Boundary | Placement | Meaning                                                                      |
| -------- | --------- | ---------------------------------------------------------------------------- |
| `acme`   | Global    | Global RP surface for the primary application runtime.                       |
| `post`   | Global    | SNS-style or in-application posts. This does not mean docs/news publication. |
| `notice` | Global    | Push notification and notification-delivery behavior.                        |
| `core`   | Regional  | Regional RP surface, parallel in kind to `acme` but region-owned.            |
| `side`   | Regional  | Region-owned RP surface.                                                     |
| `palm`   | Regional  | Region-owned RP surface.                                                     |
| `line`   | Regional  | Direct message behavior.                                                     |
| `docs`   | Global    | Documentation delivery. Content authority: central `publishing` DB.          |
| `news`   | Global    | News delivery. Content authority: central `publishing` DB.                   |
| `help`   | Global    | Help delivery. Content authority: central `publishing` DB.                   |
| `info`   | Global    | Info delivery. Content authority: central `publishing` DB.                   |

`acme` and `core` are both RP surfaces, but they do not share repository ownership: `acme` remains
global, while `core` belongs to regional.

Regional placement classifies the boundary, not the location of every line of code that serves it.
`core`, `side`, and `palm` each have a route file in this repository
(`config/routes/{core,side,palm}.rb`) carrying OIDC callbacks, sign-out, session and token
endpoints, and the surface's health and crawler routes. Those are the credential and BFF halves of a
regional surface, which is consistent with the rule below; the regional RP delivery itself is not
here. `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` records that split
for `core`. The current Edge UI origin uses TanStack Start; the ADR name retains historical Next.js
wording. Content-surface cells are listed in `docs/architecture/content-surface-matrix.md`.

## Current Rule

Do not add regional RP or direct message implementation to this repository unless a current ADR
explicitly changes the repository boundary.

For `info`, `docs`, `news`, and `help`, the current authority is the central `publishing` database
per `adr/publishing-db-content-authority.md`. Do not infer regional RP behavior, OIDC callbacks, or
preference writes from historical regional content material.

When a document says `post`, read the local context carefully:

- global `post` means SNS-style or in-application posts;
- info/docs/news/help publication is global and belongs to the `publishing` DB per
  `adr/publishing-db-content-authority.md`.

Historical Foundation / Distributor content notes should be treated as migration background only.
