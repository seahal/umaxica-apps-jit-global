# Health / revision endpoint contract migration

Date: 2026-09-03 Branch: `feature` Worktree base at start of work: `7a7a94bdd` ([CheckPoint])
Implementation landed at: `79d45d095` ([CheckPoint]) plus follow-up working-tree fixes recorded
below.

## Scope decided before implementation

The task text asked for **plural** probe paths (`/health/startups`, `/health/livenesses`,
`/health/readinesses`). Investigation of `config/routes/*.rb` showed every surface already uses
singleton `resource` (not `resources`), producing **singular** paths, which is the shape
`.agents/harnesses/rules/generic/routing.mdc` requires and which `lib/health_probe_paths.rb`,
`adr/internal-health-endpoint-edge-isolation.md`, `test/config/health_probe_paths_test.rb` and
`test/integration/edge_health_routes_test.rb` all pin. The plural request was therefore **rejected**
(confirmed with the requester): probe paths stay singular, no rename, no alias.

## Final contract

Text endpoints — `text/plain; charset=utf-8`, `Cache-Control: no-store`, no redirect, no auth, never
JSON/HTML:

| Path                    | Body (healthy)                                                                             | Unhealthy                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `GET /health`           | `status: ok` / `startup: ok` / `liveness: ok` / `readiness: ok` (one per line, that order) | overall line + failing probe line(s); HTTP from `result.http_status`          |
| `GET /health/startup`   | `ok\n`                                                                                     | `unavailable\n` + `503`                                                       |
| `GET /health/liveness`  | `ok\n`                                                                                     | `unavailable\n` + `503`                                                       |
| `GET /health/readiness` | `ok\n`                                                                                     | `unavailable\n` + `503`                                                       |
| `GET /revision`         | `<revision>\n`                                                                             | missing revision → `\n` (empty line; a missing revision stays a normal `200`) |

Machine JSON endpoints — `application/json`, `Cache-Control: no-store`, never text/plain or
text/html, `406` (empty body) when `Accept` excludes JSON:

| Path                        | Body                                                                                                               | HTTP                              |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------ | --------------------------------- |
| `GET /api/v0/health.json`   | `{"status":"pass\|warn\|fail","checks":{"startup":{"status":…},"liveness":{"status":…},"readiness":{"status":…}}}` | `pass`/`warn` → 200, `fail` → 503 |
| `GET /api/v0/revision.json` | `{"revision":"<sha>"}` or `{"revision":null}`                                                                      | 200                               |

`/api/v0/{health,revision}.json` are mounted on **all 29 surface blocks** across
`config/routes/{base,auth,info,core,side,palm,help,docs,news}.rb` via
`namespace :api { namespace :v0 { resource :health/:revision, only: :show, format: … } }` following
the existing `jwks.json` routing precedent. `bin/rails routes` shows the literal `.json` paths
(`/api/v0/health.json`, `/api/v0/revision.json`) with no `(.:format)` wildcard.

## Revision authority

`Rails.application.revision` only (framework resolves `ENV["REVISION"]` → `REVISION` file → Git).
`ApplicationRevisionRendering#application_revision` is the single code path; `render_revision`
(text) and `render_revision_json` (JSON) both call it. No `git rev-parse`, no `.git` read, no
`REVISION` file read, no `ENV` read, no SHA fabrication anywhere in application code.

## Key files

- `app/controllers/concerns/application_revision_rendering.rb` — text + JSON from one value.
- `app/controllers/concerns/health_check_rendering.rb` — `render_probe` (text), `render_snapshot`
  (text aggregate), `render_health_status` (JSON via serializer). Still delegates to
  `Health::*Check`.
- `app/controllers/concerns/machine_json_negotiation.rb` (new) — `Accept` → 406 for the `.json`
  endpoints; `no-store` on every response including the 406.
- `app/serializers/health_status_serializer.rb` (new) — maps `Health::STATUSES` (`:ok`→`pass`,
  `:degraded_acceptable`→`warn`, `:starting`→`warn`/`fail` by `result.ok?`, `:unready`→`fail`;
  `else` → `raise ArgumentError`), aggregates, owns HTTP status. Readiness failure never changes the
  liveness entry.
- `app/controllers/**/api/v0/{healths,revisions}_controller.rb` — 29 × 2, each
  `< <surface>::BareController`, `AUTHENTICATION_MODE = :bare`, `HEALTH_PROFILE` matching the
  surface's existing health controller.
- `app/views/shared/health/show.html.erb` — deleted (no remaining referrer; `/health` is text now).
- `config/routes/*.rb` (9 drawers) — `/api/v0` health+revision resources added per surface block.
- `lib/health_probe_paths.rb` — `PATHS` unchanged; comment updated to record that the `.json`
  endpoints are deliberately **not** Host-Authorization-exempt (edge-blocked, reached with a real
  `Host` already in `config.hosts`, not orchestrator probes).
- `app/services/health.rb` — added `Health::MalformedSnapshotError` (raised by `render_snapshot` if
  the aggregate is missing a probe).

## OpenAPI (3.0.4)

- `openapi/shared/paths/health-{liveness,readiness,startup}.yml` — deleted; the text probes are not
  part of the machine JSON contract.
- `openapi/shared/paths/api-v0-health.yml`, `api-v0-revision.yml` — added (200 + 503 + 406 for
  health; 200 + 406 for revision; `security: []`; unique operationIds `getApiV0Health`,
  `getApiV0Revision`).
- `openapi/shared/components.yml` — `HealthReport` schema (`status` +
  `checks.{startup,liveness, readiness}.status`, each `enum: [pass, warn, fail]`) and `Revision`
  schema (`revision: {type: string, nullable: true}` — 3.0 syntax, not the 3.1 type-array). No
  `additionalProperties: false`.
- `openapi/{app,com,org}.yml` + re-bundled `public/openapi.{app,com,org}.yml`; descriptions/tags
  rewritten to describe only the machine `/api/v0` surface.

## Tests

Representation contract (positive **and** negative assertions, per task):

- `test/integration/health_revision_contract_test.rb` (new, 383 lines) — text endpoints:
  `media_type == "text/plain"`, `!= "application/json"`, `!= "text/html"`, not redirect, body
  `!~ /\A\s*[{\[]/`, exact bodies (`"ok\n"`, the aggregate block, `"<REVISION>\n"`, `"\n"` for nil
  revision). JSON endpoints: `media_type == "application/json"`, `!= text/plain`, `!= text/html`,
  not redirect, no `<!doctype|<html`, `JSON.parse` → exact Hash / schema (revision equality; health
  `keys.sort == %w(checks status)`, `checks.keys.sort == %w(liveness readiness startup)`, each check
  `keys == %w(status)`, status ∈ `%w(pass warn fail)`). `Accept` regression (text stays text under
  `application/json` / `text/html` / `*/*`; JSON → 406 under `text/html` / `text/plain`). `no-store`
  everywhere. `HEAD /revision` = GET status/CT/cache, empty body. `assert_no_queries` for
  `/revision` and `/api/v0/revision.json`. Health-JSON leak guard (no `Rails.root`, host,
  `secret_key_base`, `"git"`, backtrace, exception class). Forced readiness failure →
  `/api/v0/health.json` `status: "fail"` + `liveness: "pass"` + HTTP 503; `/health/readiness` 503;
  `/health/liveness` still `"ok\n"` 200.
- `test/integration/revision_endpoint_test.rb` — migrated to text/plain; keeps every prior guarantee
  (per-surface routing, shared concern, `:bare`, same revision across surfaces, nil behaviour,
  verbatim pass-through, no auth redirect, `assert_no_queries`, leak guard, HEAD, unknown-host
  `RoutingError`); adds the `/api/v0/revision.json` symmetric block.
- `test/integration/health_endpoints_test.rb`, `test/integration/health_check_test.rb` — probes
  migrated to text; `/health` migrated to text aggregate; old `/health.json → 406` replaced with the
  symmetric contract; `/api/v0/health.json` schema + status + leak + 406 coverage added; profile
  isolation / namespace uniqueness / dependency-free liveness / wrong-host / missing
  `HEALTH_PROFILE` retained.
- `test/integration/edge_health_routes_test.rb` — legacy singular-pair + `/health.json` +
  `/v1/health` 404 guards retained/extended.
- `test/serializers/health_status_serializer_test.rb` (new) — status mapping table, aggregation,
  HTTP status, `raise` on unmapped status.
- `test/contracts/openapi_health_contract_test.rb` — real `GET /api/v0/health.json` per surface →
  `assert_openapi_conform 200`; forced failure → `assert_openapi_conform 503`; `Accept: text/html`
  → 406.
- `test/contracts/openapi_revision_contract_test.rb` (new) — `GET /api/v0/revision.json` →
  `assert_openapi_conform 200`; `Accept: text/html` → 406.
- `test/contracts/openapi_document_validity_test.rb` (new) — YAML parse, OpenAPI 3.0.4 validity,
  `$ref` resolution, no duplicate operationId, no 3.1-only syntax, app/com/org divergence guard.
- `test/contracts/openapi_route_coverage_test.rb` — `/health` text routes excluded from the
  "described" expectation; `/api/v0/{health,revision}.json` required for app/com/org.
- `test/controllers/**/healths_controller_test.rb`,
  `test/controllers/base/app/bare_controller_test.rb` (`Api::V0::{Healths,Revisions}Controller`
  added to `REQUIRED_DESCENDANTS` — a deliberate, reviewed addition of two public, self-defending
  bare endpoints).

## Commands and results

| Command                                                                     | Result                                                                                                         |
| --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `bin/rails test test/integration/health_revision_contract_test.rb …8 files` | 119 runs, 3728 assertions, **0 failures, 0 errors**                                                            |
| `bin/rails test test/contracts`                                             | 115 runs, 1271 assertions, **0 failures, 0 errors**                                                            |
| `pnpm openapi:lint`                                                         | app/com/org **valid**                                                                                          |
| `pnpm openapi:verify` (bundle + `git diff --exit-code`)                     | **clean** (bundles regenerate identical)                                                                       |
| `bin/rubocop` (99 changed Ruby files)                                       | **0 offenses** (after 1 autocorrect in the entries contract test)                                              |
| `git diff --check`                                                          | **clean**                                                                                                      |
| `bin/rails test` (full suite, after the follow-up fixes)                    | 12254 runs, 69283 assertions, **3 failures + 3 errors, all pre-existing** (below); 0 introduced by this change |
| `bin/rails test test/integration`                                           | 1060 runs; green after removing the obsolete HTML `/health` title test                                         |

### Follow-up test fixes made after the first full run (all test-only)

- `test/controllers/base/app/bare_controller_test.rb` — added the two new `Api::V0` controllers to
  `REQUIRED_DESCENDANTS` (deliberate: they are public, self-defending bare endpoints).
- `test/integration/html_title_contract_test.rb` — removed the `"health snapshot takes its TLD…"`
  test and the `HEALTH_HOSTS` constant (both assumed HTML `/health`); widened
  `NON_HTML_PATH_PATTERNS` to `%r{\A/health(/(liveness|readiness|startup))?\z}`.
- `test/unit/security/public_entrypoint_inventory_test.rb` — `public_health?` / `public_revision?`
  now also match `/api/v0/health.json` / `/api/v0/revision.json` (categories `PUBLIC_HEALTH` /
  `PUBLIC_REVISION`, already documented in `docs/security/public-entrypoints.md`).

## Remaining / out-of-scope issues

1. **Pre-existing, unrelated failures** — 4 failures + 3 errors, none involving health/revision.
   Verified against `7a7a94bdd`: the referenced files/constants are absent there too, and the test
   files are untouched by this change.
   - `ControllerInheritanceInvariantTest` — `KNOWN_VIOLATIONS` lists
     `base/org/support/{clients,operators}/sessions/emergency_revocations_controller.rb`, absent.
   - `RiRoutingContractTest#test_set_region_is_skipped_only_in_the_reviewed_allowlist` and
     `ForbiddenRailsPatternsTest#test_verification_and_client-auth_before_actions…` — both allowlist
     `app/controllers/base/{app,com,org}/edge/v0/dbsc_controller.rb`, which is **absent at
     `7a7a94bdd` and at HEAD** (an incomplete `edge/v0/dbsc` → `edge/v0/token/dbsc` refactor already
     on the branch).
   - `Base::Org::Edge::V0::DbscControllerTest` — references `Base::Org::Edge::V0::DbscController`;
     same incomplete refactor.
   - `ComposeLocalOverrideOptionalTest` ×2 — `compose.override.yaml.example` does not exist on disk;
     no compose file is in this change.
   - `AcmeRootsTest#…:59` — **passes in isolation**; full-run-only test pollution.
   - (`BasePalmSurfaceSmokeTest` `GET /health` → 503: also isolation-passes, readiness sees shared
     DB state; not a contract defect — old HTML `/health` used the same `result.http_status`.)
2. **Scope creep introduced by the migration workflow** — the OpenAPI agent also renamed the
   unrelated `GET /api/v0/entries/{slug}` path parameter to `{public_id}` and touched
   `app/serializers/publishing_entry_serializer.rb`,
   `app/queries/publishing_published_entries_query.rb`, and several `test/contracts/*entries*` /
   `publishing_*` tests. These are already committed in `79d45d095`. They are green but are **not**
   part of the health/revision contract and should be reviewed / reverted separately if unwanted.

## Evidence layout

`test/tooling/evidence_layout_test.rb` — flat, `.md` only, `YYYY-MM-DD-<topic>.md`: satisfied.
