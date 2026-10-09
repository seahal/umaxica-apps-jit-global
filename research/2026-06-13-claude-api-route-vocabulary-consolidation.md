# API Route Vocabulary Consolidation Toward `/api/v0`

Companion field notes for `adr/api-route-vocabulary-consolidation.md`. Facts come from
`config/routes/*.rb` and a repo-wide search on 2026-06-13. Recommendations are labeled as such and
are not implemented.

## Context

The app exposes versioned machine-facing endpoints under two unrelated top-level namespaces
(`web/v0`, `edge/v0`). The ADR records a direction to converge API routes toward `/api/v0`. This
memo captures the observed vocabulary, the reasoning, a proposed future classification process, the
candidate inventory, risks, and open questions. Nothing here changes routes.

## Current observed route vocabulary (facts)

`web/v0` (comment: `Public web API`):

- `acme.rb`, `core.rb`: `web/v0/cookie` (show/update), `web/v0/theme` (show/update).
- `sign.rb`: `web/v0/cookie`, `web/v0/theme`, plus OTP delivery `web/v0/in/email/otp` (create) and
  `web/v0/in/telephone/otp` (create).

`edge/v0` (comment: `Edge API` / `Edge API: token lifecycle management`):

- `acme.rb`: `edge/v0/token/check` (show), `edge/v0/token/dbsc` (create), `edge/v0/token/refresh`
  (create), `edge/v0/cookie` (show/update), `edge/v0/dbsc` (create).
- `sign.rb`: `edge/v0/token/check` (show), `edge/v0/token/dbsc` (create).
- `core.rb`: `edge/v0/cookie` (show/update), `edge/v0/dbsc` (create).
- `docs.rb`, `help.rb`, `news.rb`: `edge/v0/entries` (index/show).

No `api/v0` namespace exists anywhere today (repo-wide search returned no matches).

Cross-references that pin the current vocabulary (will matter for any future migration):

- JS clients hardcode paths: `app/javascript/controllers/cookie_banner_controller.js`,
  `cookie_toggle_controller.js`, `theme_controller.js` use `/web/v0/cookie` and `/web/v0/theme`.
- Controller logic keys off the path: `app/controllers/concerns/authentication_base.rb`
  special-cases `/edge/v0/token/refreshes`.
- Many tests and invariants reference `/web/v0/...` and `/edge/v0/...` (integration, controller,
  security invariant, and JS tests).

## Why `web` and `edge` are confusing as long-term API namespace names

- The names encode historical _implementation assumptions_ (how an endpoint was expected to be
  served), not a boundary that API clients care about. To a client both are just API endpoints.
- `edge` is overloaded: under one name it carries token lifecycle, preference writes (cookie/dbsc),
  and content reads (`entries`). A single namespace spanning three unrelated concerns is a weak
  long-term contract.
- The two namespaces overlap in function: `cookie` exists under _both_ `web/v0` and `edge/v0`, so
  the `web` vs `edge` split does not cleanly partition behavior.
- Versioning is ambiguous: `v0` lives under two unrelated prefixes, so "the v0 API" has no single
  meaning.

## Proposed future classification process (recommendation)

Before migrating any endpoint, classify it (per-endpoint, not per-namespace):

1. Is it an _actual API endpoint_ (machine-facing data/action consumed by a client)? → candidate for
   `/api/v0`.
2. Is it a _protocol, ceremony, or operational_ endpoint (auth/OIDC/OmniAuth callback, SSO,
   `.well-known`, health, browser ceremony, human-facing HTML)? → not auto-moved; leave outside
   `/api/v0` unless a later ADR moves it explicitly.
3. For each candidate, decide the compatibility mechanism (redirect, alias, or dual route support)
   and confirm no client breaks before changing the live path.
4. Defer genuinely ambiguous endpoints (record as UNKNOWN) rather than guessing.

## Candidate routes for future `/api/v0` migration (recommendation, not implemented)

Following the task's candidate categories, mapped to observed routes:

- Browser fetch API endpoints — `web/v0/cookie`, `web/v0/theme` (consumed by the JS controllers
  above).
- Token check API endpoints — `edge/v0/token/check`.
- DBSC binding API endpoints — `edge/v0/token/dbsc`, `edge/v0/dbsc`.
- Token refresh API — `edge/v0/token/refresh`.
- OTP delivery endpoints when treated as API — `web/v0/in/email/otp`, `web/v0/in/telephone/otp`.
- Cookie/theme preference API endpoints when still Rails-owned — `web/v0/cookie`, `web/v0/theme`,
  `edge/v0/cookie`.
- iOS / web / native client API endpoints — listed as a category by the task. UNKNOWN: route
  definitions do not prove which endpoints map to iOS vs browser vs other clients; confirm before
  migrating on that basis.
- `edge/v0/entries` (docs/help/news content reads) — open classification question; requires separate
  review. Not classified here.

Naming direction (recommendation): `/web/v0/...` → `/api/v0/...` and `/edge/v0/...` → `/api/v0/...`.

## Routes that should remain outside `/api/v0` (facts about category, recommendation about exclusion)

Not automatically part of the consolidation; keep outside `/api/v0` unless a later ADR moves them:

- `/auth/...` — OAuth/OIDC callback and OmniAuth callback routes (e.g. `auth/callback`,
  `social/auth`).
- `/sso/...` — e.g. `sso/authorize`, `sso/logout`.
- `/.well-known/...` — e.g. `.well-known/jwks.json`.
- `/health/...` — `health`, and `health/{liveness,readiness,startup}`.
- Browser ceremony routes — e.g. the sign-in / sign-up flow routes in `config/routes/sign.rb`.
- Human-facing HTML routes.

## Risks

- Large blast radius: `/web/v0` and `/edge/v0` are referenced in JS clients, a controller concern
  that branches on the path, and many tests/invariants. A naive rename breaks all of them.
- Hardcoded client paths (the JS controllers) mean a server-only rename is insufficient; clients and
  any cached/native consumers must be coordinated.
- Dual-route / alias periods add surface area and can drift if not removed on a tracked schedule.
- Misclassification risk: moving a protocol/ceremony endpoint under `/api/v0` would blur a security
  or lifecycle boundary. The per-endpoint rule exists to prevent this.
- `edge/v0` overloading means migrating "edge" wholesale would wrongly bundle token, preference, and
  content concerns together.

## Open Questions

- Which clients consume each namespace (browser vs iOS vs other)? Currently UNKNOWN from routes.
- Should `/api/v0/entries` (content reads) be in scope at all, or stay separate? Deferred.
- Does the API version stay `v0` after consolidation, or does consolidation coincide with a version
  bump?
- Compatibility mechanism of record: redirect vs alias vs dual route — decide per endpoint at
  migration time.
- Sequencing: server routes, helpers, JS clients, and tests must move together; ordering is TBD.

## Promotion Candidate

The stable decision is recorded in `adr/api-route-vocabulary-consolidation.md`. When a migration is
actually scheduled, promote the classification process and candidate inventory into a
`plans/active/` plan (not created here, per task scope).
