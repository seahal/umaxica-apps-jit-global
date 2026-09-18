# Core API route migration evidence

Date: 2026-09-15

## Scope

The Core app, com, and org preference endpoints were moved from historical controller namespaces
to `Core::<surface>::Api::V0::Preferences` while keeping the public paths unchanged:

- `GET/PATCH /api/v0/preferences/cookie`
- `GET/PATCH /api/v0/preferences/theme`
- `POST /api/v0/preferences/dbsc`

The unmounted Core `Web::V0` and `Edge::V0` controller files for these endpoints were removed.
The DBSC endpoint remains protocol-owned and uses resource routing. Cookie and theme keep explicit
GET/PATCH declarations because Rails resource update routing would add PUT, which is outside the
existing OpenAPI and route contract.

## Verification

- `RUBY_DEBUG_LAZY=1 bin/rails routes` exited 0 and showed all nine routes resolving to the
  canonical API controller paths.
- A read-only `RUBY_DEBUG_LAZY=1 bin/rails runner '...'` route-recognition check exited 0 for
  app/com/org GET, PATCH, and DBSC POST requests and confirmed that cookie/theme PUT requests still
  raise `ActionController::RoutingError`.
- A read-only Rails runner loaded all canonical controller constants and confirmed the app DBSC
  controller exposes the generated `core_app_api_v0_preferences_dbsc_url` helper used for its
  protocol audience.
- A repository search found no remaining Core `Web::V0` / `Edge::V0` controller-path references in
  `app`, `lib`, `config`, or tests; remaining legacy vocabulary belongs to other services or
  documented historical evidence.
- `RUBY_DEBUG_LAZY=1 bin/rails runner '...'` exited 0 and loaded the canonical cookie, theme, and
  DBSC controller constants.
- Ruby syntax checks for routes, controllers, and affected tests passed.
- Targeted RuboCop over 18 affected Ruby files passed with no offenses.
- Full `bundle exec rubocop` inspected 4,786 files and exited 0 with no offenses.
- `git diff --check` passed.
- `bun run openapi:lint` exited 0; no OpenAPI shape changed.
- `bun run openapi:verify` exited 0; bundling was deterministic and produced no generated-bundle
  diff.
- `RUBY_DEBUG_LAZY=1 bin/rails notes` exited 0.

The notes output includes new actionable `FIXME:` entries on the intentionally deferred Base/Side
browser preference routes and Base token/DBSC protocol routes. Those endpoints were not renamed
without a caller, authority, and compatibility decision.

The route contract, DBSC wiring, preference registry, and security invariant Rails tests could not
execute assertions because test boot requires PostgreSQL host `primary`, which is not resolvable in
the current environment. No database, Valkey, or external provider was started or modified.

## Follow-up coverage boundary

The OpenAPI route-coverage discovery pattern now explicitly includes the `edit` service. A
read-only runner inventory found exactly Edit's two org operational operations:
`GET /api/v0/health.json` and `GET /api/v0/revision.json`; both are present in the existing org
OpenAPI description. GUID's `GET /api/v0/resources/:guid` remains outside the three-surface
documents because its `net` ownership and durable resolver contract are unresolved. An actionable
FIXME was added next to that route rather than inventing a schema or persistence model.

`bundle exec rubocop test/contracts/openapi_route_coverage_test.rb config/routes/guid.rb`, Ruby
syntax checks, `RUBY_DEBUG_LAZY=1 bin/rails notes`, the route inventory, and `git diff --check`
passed. The OpenAPI coverage Minitest was attempted but stopped before assertions with
`PG::ConnectionBad: could not translate host name "primary" to address`.
### Active preference contract reconciliation

The active `docs/architecture/preference-behavior-contract.md` had one stale sentence saying
cookie and theme JSON endpoints remained under `/web/v0` on every surface. It now records the
current split: Core uses `/api/v0/preferences/{cookie,theme}`, while non-Core browser endpoints
remain under legacy `/web/v0` until a separately reviewed migration. Its callback-parity guidance
names both the non-Core legacy controllers and the canonical Core controllers. This was a
documentation-only correction; no additional route or behavior changed.

### Cookie scope cross-check

A read-only Rails runner instantiated `AuthenticationCookieService` with request objects for app,
com, and org hosts. Issuance and deletion options matched for `path`, `domain`, `same_site`, and
`secure`, and deletion omitted `expires`. No database, Valkey, or browser state was touched. This
is source/options evidence only; the complete sign-out cookie-jar request remains unverified.

## Session absolute-expiry recheck

Read-only source inspection confirmed that the existing session inventory already treats the token
row's finite `discarded_at` as the fixed session deadline. Rotation copies it unchanged;
`SessionAbsoluteExpiryValue` caps token and cookie lifetimes; refresh and session-authentication
scopes reject the row at or after it. The Base identity presenter exposes this value only as
user-facing `expires_at` and keeps refresh-token expiry, identifiers, binding, generation, and raw
context out of the UI. Existing unit/service/integration tests cover the invariant for app, com,
and org. No new schema or code change was made. Full DB-backed and browser checks remain pending
because the test PostgreSQL host `primary` is not resolvable in this environment.

The full `bundle exec rubocop --cache false` was rerun after the route and presenter checks. It
inspected 4,786 files and exited 0 with no offenses. This supersedes an earlier intermediate run
that reported a pre-existing PGHero line-length offense; the PGHero route was not changed.

`bun run openapi:lint && bun run openapi:verify` exited 0. Redocly validated app/com/org source
documents, regenerated the committed bundles, and the verification diff was empty.
