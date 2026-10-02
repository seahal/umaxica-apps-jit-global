# API Route Vocabulary Consolidation Toward `/api/v0`

Current naming note (2026-09-25): references to the Rails `Side` surface in this historical route
vocabulary decision describe the current `Warp` internal namespace. Public routes and protocol
identifiers retain their established values.

**Status:** Accepted; Core preference API migration amended (2026-09-15); Base, Auth, and Warp
preference API migration amended (decision approved 2026-10-01; implemented 2026-10-02)

> The original decision recorded a route-naming direction only. Its implementation amendment below
> records the first separately reviewed migration slice; the remaining legacy namespaces are still
> governed by the original decision.

## Status

Accepted (2026-06-13); amended for the Core preference migration (2026-09-15) and for the Base, Auth,
and Warp preference migration (decision approved 2026-10-01; implemented 2026-10-02).

This decision establishes preferred long-term vocabulary for API route namespaces. It is a naming
and direction decision. The implementation amendment below records a reviewed Core preference API
migration; recording the original decision alone did not add, remove, redirect, or alias routes.

## Context

The repository currently exposes versioned machine-facing endpoints under two separate top-level
route namespaces, both at version `v0`.

Observed facts (from `config/routes/*.rb` and route comments as of 2026-06-13):

- `web/v0` namespaces exist in `config/routes/acme.rb`, `config/routes/core.rb`, and
  `config/routes/sign.rb`. The route comment labels them `Public web API` (acme, sign) and they
  carry `cookie` (show/update), `theme` (show/update), and — in `sign.rb` only — OTP delivery
  (`web/v0/in/email/otp`, `web/v0/in/telephone/otp`, both `create`).
- `edge/v0` namespaces exist in `config/routes/acme.rb`, `config/routes/core.rb`,
  `config/routes/sign.rb`, `config/routes/docs.rb`, `config/routes/help.rb`, and
  `config/routes/news.rb`. The route comment labels them `Edge API` /
  `Edge API: token lifecycle management`. They carry: token lifecycle (`edge/v0/token/check`,
  `edge/v0/token/dbsc`, `edge/v0/token/refresh`), preference (`edge/v0/cookie`, `edge/v0/dbsc`), and
  content reads (`edge/v0/entries`, index/show, under docs/help/news).
- No `api/v0` namespace exists anywhere in the repository today (repo-wide search returned no
  matches).

The names `web` and `edge` originate from differing historical implementation assumptions about how
each endpoint group would be served. For API clients, the distinction these names encode is no
longer a useful stable boundary: from a client's perspective, both namespaces are simply API
endpoints. The split also makes `v0` versioning ambiguous, because the same version number lives
under two unrelated prefixes.

UNKNOWN: the precise client mapping for each namespace (for example, which endpoints are consumed by
browser fetch versus an iOS or other native client) is not established by route definitions alone
and is not asserted here. The route comments state intent (`Public web API`, `Edge API`) but do not
prove a per-client mapping.

## Decision

`/api/v0` is the preferred long-term namespace for the application's API routes.

`/web/v0` and `/edge/v0` are treated as legacy / transitional API route vocabulary. Future API
routes, and future migrations of existing API routes, should converge toward `/api/v0/...` as the
canonical namespace.

This is a vocabulary decision only. No routes are changed in this task.

### Classification rule

The convergence applies to _actual API endpoints_. Protocol, ceremony, and operational endpoints are
not blindly moved under `/api/v0`. Whether a given endpoint is an "actual API endpoint" for the
purpose of this rule must be decided per endpoint during later, separately reviewed migration work.

## Scope

In scope for this decision:

- The naming of API route namespaces.
- The direction that API route namespaces should consolidate under `/api/v0`.
- The future migration direction from `/web/v0` and `/edge/v0` toward `/api/v0`.
- Documenting compatibility requirements that future migration must satisfy.
- Documenting that any actual implementation must happen later.

## Non-scope

This decision does not cover and does not authorize:

- Controller, model, migration, or test changes.
- Any route addition, deletion, redirect, alias, or compatibility shim.
- Changes to route helpers or path helper names.
- API response schema changes.
- Frontend ownership, content-surface design, or HTML rendering concerns.
- Integration decisions for any specific runtime or framework.

The following existing route categories are **not** automatically part of this decision and may
remain outside `/api/v0` unless a later ADR explicitly moves them:

- `/auth/...` (including OAuth/OIDC callback and OmniAuth callback routes).
- `/sso/...`.
- `/.well-known/...`.
- `/health/...` and its liveness/readiness/startup children.
- Browser ceremony routes (for example the sign-in / sign-up flow routes).
- Human-facing HTML routes.

## Consequences

- A single canonical API namespace (`/api/v0`) gives clients one stable vocabulary and removes the
  `web` versus `edge` distinction, which no longer carries useful meaning for API consumers.
- For endpoints not yet migrated, current clients and tests that reference `/web/v0/...` and
  `/edge/v0/...` continue to work unchanged. The Core preference amendment has its own reviewed
  compatibility boundary; it does not imply that other legacy endpoints have moved.
- Future migration work will need to reconcile a large existing surface: `/web/v0` and `/edge/v0`
  paths are referenced across JavaScript controllers, controller concerns, and tests, so any actual
  move is a cross-cutting change requiring its own plan and review.
- The per-endpoint classification rule means migration is not mechanical; each endpoint must be
  judged as an actual API endpoint versus a protocol/ceremony/operational endpoint before it is
  considered for `/api/v0`.

## Compatibility requirements

These requirements constrain any _future_ implementation; they are not actions taken in this task.

- Future route migration requires a compatibility review before any path changes.
- Future route migration may require redirects, aliases, or dual route support (serving both the
  legacy and the `/api/v0` path) to avoid breaking existing clients.
- `/web/v0` and `/edge/v0` must not be removed as part of recording this decision, and must not be
  removed by future work until compatibility review confirms it is safe.
- Protocol and operational endpoints (see Non-scope) are not automatically moved to `/api/v0`.

## Future implementation notes

- Remaining endpoint migrations must happen under their own plan and review; the Core preference
  slice is the separately reviewed implementation amendment below.
- A future migration should begin by classifying each existing `web/v0` and `edge/v0` endpoint as an
  actual API endpoint or a protocol/ceremony/operational endpoint, then migrating only the former.
- The content-read endpoints `/edge/v0/entries` (docs/help/news) are an open classification question
  and require separate review before any decision; they are intentionally not classified here.
- Exploratory implementation notes, the candidate-route inventory, risks, and open questions are
  recorded in `memos/2026-06-13-claude-api-route-vocabulary-consolidation.md`.

## Implementation amendment — Core preference APIs (2026-09-15)

The following reviewed migration slice is now implemented on the `feature` branch:

- Core app, com, and org preference cookie and theme endpoints remain at their established
  `/api/v0/preferences/{cookie,theme}` paths, but their controllers now live under the matching
  `Core::<surface>::Api::V0::Preferences` namespace.
- Core DBSC registration remains the protocol endpoint `POST /api/v0/preferences/dbsc` and now uses
  the same canonical API namespace.
- The old Core `Web::V0` and `Edge::V0` controller files for these endpoints were removed after
  route and source searches showed no remaining application caller.
- The cookie/theme routes intentionally remain explicit `GET` + `PATCH` declarations. Rails'
  resource update mapping also exposes `PUT`, while the existing OpenAPI documents and route
  contract intentionally allow only `PATCH`; changing that verb contract would be an unrelated API
  change. The DBSC endpoint uses ordinary resource routing because its protocol contract is `POST`
  only.

This amendment does not migrate Auth, Base, Side, Docs, Help, News, or other protocol/ceremony
endpoints. Their legacy route vocabulary remains subject to endpoint-specific compatibility review.
(The Base, Auth, and Side/Warp theme and cookie endpoints were since migrated by the 2026-10-02
amendment below.)
The route contract, DBSC wiring, preference registry, and security invariant tests were updated to
follow the canonical controller locations. Runtime request tests remain required before accepting
the migration because the current environment has no reachable isolated PostgreSQL/Valkey targets.

## Implementation amendment — Base, Auth, and Warp preference APIs (2026-10-02)

Decision approved 2026-10-01 by the user's preference transport instruction; implemented
2026-10-02. The family capability and host-local transport rationale is recorded in
`adr/preference-browser-transport-family-capability.md`.

Classification (per the rule above): `/web/v0/theme` and `/web/v0/cookie` are actual API endpoints.
`POST /web/v0/in/email/otp` is a ceremony endpoint and is not part of this amendment; `/edge/v0/*`
is not part of it either.

- Base, Auth, and Warp app, com, and org now serve `GET`/`PATCH /api/v0/preferences/{theme,cookie}`
  with controllers under `<Family>::<Surface>::Api::V0::Preferences`, the same paths and HTTP
  contract as Core. Their `/web/v0/{theme,cookie}` routes and `Web::V0` theme and cookie controllers
  are removed.
- **Pre-deployment internal breaking cutover.** The compatibility requirements above ("may require
  redirects, aliases, or dual route support"; "must not be removed … until compatibility review
  confirms it is safe") and the Deprecation/Sunset rule of `docs/reference/api-design-standards.md`
  exist to protect deployed clients. The compatibility review for this slice found none: the only
  callers were this repository's own browser code (`src/lib/theme.ts`,
  `src/components/chrome/CookieBanner.tsx`, and the `theme`, `cookie-banner`, and `cookie-toggle`
  Stimulus controllers), which move in the same change; neither endpoint is in any OpenAPI document;
  the Next.js edge application forwards only `/api/v0/*` (`plans/analysis/rails-nextjs-openapi-contract-audit.md`,
  decision D14); and the application has not been deployed. The legacy paths are therefore removed
  without a Sunset window, redirect, alias, or dual route. This is not a removal of a published
  client contract, and it does not relax the Sunset rule for any endpoint that has a deployed client.

### Route exception record (routing harness)

| Field | Value |
| --- | --- |
| Date | Approved 2026-10-01; implemented 2026-10-02 |
| Status | Accepted, permanent |
| Route files | `config/routes/base.rb`, `config/routes/auth.rb`, `config/routes/warp.rb` (app, com, org blocks) |
| Snippet | `namespace :api { namespace :v0 { namespace :preferences { get :cookie, to: "cookies#show"; patch :cookie, to: "cookies#update"; get :theme, to: "themes#show"; patch :theme, to: "themes#update" } } }` |
| Exception type | Explicit `get` / `patch` with `to:` instead of `resource` |
| Reason | `resource … only: %i(show update)` also maps `PUT`; the shared contract and the OpenAPI documents allow only `PATCH`, matching the Core precedent in the 2026-09-15 amendment |
| Approval source | The user's 2026-10-01 instruction ("PUT is not added; respect Core's explicit GET + PATCH; record the same exception in an accepted ADR") |
| Lifetime | Permanent while the preference APIs keep a `PATCH`-only update contract |
| Removal plan | Replace with a resourceful route only if Rails offers a `PATCH`-only update mapping or the contract adopts `PUT` |
| Tests | `test/integration/routes/{base,auth_sign_ceremony,warp,core}_route_contract_test.rb`, `test/integration/routes/legacy_api_namespace_guard_test.rb`, `test/integration/preference_browser_api_contract_test.rb`, `test/contracts/openapi_route_coverage_test.rb` |
| Controller/action | `{base,auth,warp}/{app,com,org}/api/v0/preferences/{cookies,themes}#{show,update}` |
| Helper / path / verb | `<family>_<surface>_api_v0_preferences_{cookie,theme}`; `GET` and `PATCH /api/v0/preferences/{cookie,theme}`; no `PUT` |
| Risk | Low: same-origin JSON endpoints behind the family's forgery protection; an accidental `PUT` mapping is caught by the route contract tests |

