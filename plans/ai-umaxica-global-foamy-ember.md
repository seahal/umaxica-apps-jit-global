# Plan: rails_performance / Coverband / Swagger UI on dedicated `*.umaxica.dev` hosts

## Context

The Global Rails application has four operator dashboards (Mission Control Jobs, Flipper UI, Blazer,
PgHero), each on its own dedicated `*.umaxica.dev` host reached through Cloudflare Tunnel. It has no
server-side performance dashboard, no production-code-execution observability, and no rendered view
of the OpenAPI descriptions it already maintains under `openapi/`.

This adds three more diagnostic surfaces using the **same four-part pattern** the existing four use,
so no new host/auth mechanism enters the codebase:

| Surface           | Public host               | Development alias                | Purpose                                                                    |
| ----------------- | ------------------------- | -------------------------------- | -------------------------------------------------------------------------- |
| rails_performance | `performance.umaxica.dev` | `performance.core.dev.localhost` | request latency, per-controller percentiles, throughput, DB/view breakdown |
| Coverband         | `coverband.umaxica.dev`   | `coverband.core.dev.localhost`   | which Ruby code actually executed                                          |
| Swagger UI        | `swagger.umaxica.dev`     | `swagger.core.dev.localhost`     | renders the existing per-surface OpenAPI descriptions                      |

Cloudflare Tunnel/DNS/Access changes are **out of scope**; this plan only makes Rails able to serve
these hosts correctly.

### Two user decisions already taken

1. **`performance.umaxica.dev`** — the request said `performace.umaxica.dev`; confirmed as a typo
   and corrected. The Cloudflare DNS record must be created with the corrected spelling.
2. **`group :development` only** — same as `pghero` / `blazer` / `rails_db`. Consequence to record
   in the ADR: **Coverband will only observe development code execution, not production.** That is a
   deliberate departure from Coverband's usual purpose. Section 6 of the request
   ("production相当環境で") is therefore _not_ satisfied; promoting to
   `group :development, :production` is a separate, later decision that must also revisit
   `mounted_engine_invariant_test.rb`.

### Execution constraint for this session

This host does not run Rails (`bundle install` is intentionally incomplete — see
`project_host_does_not_run_rails` memory). **No test in this plan can be executed here.** All code
and tests will be written statically; `bin/rails test` runs inside the container on the next build.
The completion report must list every check as unverified rather than claim it passed.

---

## The pattern being followed

Established by `config/routes/pghero.rb` + `config/initializers/pghero.rb`. Adding a tool host is
exactly five edits:

1. `config/routes/<tool>.rb` —
   `constraints host: [ENV["PUBLIC_<TOOL>_URL"], ENV["PRIVATE_<TOOL>_URL"], "<tool>.core.dev.localhost"].compact`
   wrapping a `mount`, guarded by `if defined?(...)`.
2. `config/initializers/<tool>.rb` — `if Rails.env.development?` + fail-closed `Rack::Auth::Basic`
   on the engine's own middleware stack, credentials via
   `Rails.app.creds.option(:<TOOL>_USERNAME/_PASSWORD)`, compared with non-short-circuiting `&` +
   `ActiveSupport::SecurityUtils.secure_compare`.
3. `config/application.rb` — explicit `require` inside the existing `if Rails.env.development?`
   block (engines contribute routes through `add_routing_paths`, which runs before
   `config/initializers/*`).
4. `app/values/fqdn_availability_registry.rb` — a `SLOT_SOURCES` entry (an invariant test fails on
   drift).
5. `config/environments/development.rb` — `PUBLIC_/PRIVATE_<TOOL>_URL` in `env_host_keys`, and
   `<tool>.core.dev.localhost:3000` / `:3001` in `localhost_tunnel_hosts`.

Plus `.devcontainer/compose.yaml` `networks.frontend.aliases` on the `core` service (both the
`.core.dev.localhost` and `.umaxica.dev` forms, as `mission|flipper|blazer|pghero` already do), and
`.env.example` / `.env.devcontainer.example`.

`config/environments/production.rb` is **not** touched: no `*.umaxica.dev` host is in the production
`config.hosts` literal today, and these gems are development-only. This satisfies "3
FQDN が必要な環境でのみ許可される" and never widens to `*.umaxica.dev`.

---

## Step 1 — Gems and lockfile

`Gemfile`, inside `group :development`, each with a comment naming the risk (matching the `rails_db`
comment style):

```ruby
# Server-side request performance dashboard. Development only: its own config/routes.rb calls
# `Rails.application.routes.draw { mount RailsPerformance::Engine => RailsPerformance.mount_at }`
# unconditionally, with no flag to disable it — see config/initializers/rails_performance.rb for
# how that unconstrained mount is neutralised.
gem "rails_performance", require: false
# Runtime code-execution coverage. Development only (see plans/…): it therefore observes
# development execution, not production.
gem "coverband", require: false
# Swagger UI and the OpenAPI document endpoint it reads, on swagger.umaxica.dev.
gem "rswag-ui", require: false
gem "rswag-api", require: false
```

Target versions (current stable as of 2026-09-17): `coverband 6.2.2`, `rails_performance 1.6.0`,
`rswag-ui`/`rswag-api 2.17.0`. Pin with `~>` only if resolution against Rails main forces it.

Run `bundle lock` (not `bundle install`) to update `Gemfile.lock` — network is reachable here and
`bundle lock` writes no gems and starts nothing. Record the resolved versions for the report.

**Risk:** Rails comes from `rails/rails` main. These gems declare `>= 6/7` Rails dependencies; a
resolution conflict or a runtime incompatibility with Rails main is plausible and will only surface
in the container. If `bundle lock` fails here, stop and report rather than loosening constraints.

## Step 2 — Valkey responsibility

`lib/umaxica/valkey/responsibility_urls.rb` — add a fourth responsibility:

```ruby
DEV_DBS  = { cache: 0, rate_limit: 1, auth_state: 2, observability: 6 }.freeze
TEST_DBS = { cache: 3, rate_limit: 4, auth_state: 5, observability: 7 }.freeze
```

`OBSERVABILITY_REDIS_URL` is the ENV name (follows `<RESPONSIBILITY>_REDIS_URL`). Deliberately
**not** added to `Umaxica::Valkey::TestTarget::URL_NAMES`: test never connects (gems absent from the
test group), so requiring the variable at test boot would be configuration that fails for no reason.

Logical separation within DB 6 is by namespace:

- rails_performance: `rails_performance:` (gem's own key prefix)
- Coverband: `coverband:` via `redis_namespace: "coverband"`

Both resolve the URL with one-argument `ENV.fetch("OBSERVABILITY_REDIS_URL")` **inside the
development guard**, so a missing URL fails the boot loudly instead of falling back to
`redis://127.0.0.1:6379/0` (which is both gems' documented default and would silently land on the
cache DB). No `||` default, no two-arg fetch.

Update `adr/valkey-nonprod-logical-db-topology.md` with DB 6/7, and add
`OBSERVABILITY_REDIS_URL=redis://valkey:6379/6` to `.env.example`, `.env.devcontainer.example`, and
the `core` service environment in `.devcontainer/compose.yaml`.

## Step 3 — Swagger, and moving the OpenAPI bundle out of `public/`

### 3a. Move the bundled output

Today `public/openapi.{app,com,org}.yml` is the bundle every consumer reads. In **development**
`config.public_file_server.enabled = true`, so those files are fetchable unauthenticated from any
admitted dev host. (In production `public_file_server.enabled = false`, so there is no production
exposure — state this plainly in the report.)

`redocly.yaml` already records the intent: _"This is a first-party internal API description, not a
published artifact."_ Moving it out of `public/` follows that stated intent rather than reversing a
publishing decision, so the "do not un-publish without investigating intent" caveat is satisfied.

Move to `openapi/bundled/openapi.{app,com,org}.yml` and update every reference in one commit:

- `redocly.yaml` — the three `output:` paths and the header comment
- `package.json` — `openapi:verify`'s `git diff --exit-code` paths
- `lefthook.yml:12` — the formatter exclusion glob
- `test/support/openapi_contract.rb` — `OpenapiContract.schema_path` becomes
  `Rails.root.join("openapi/bundled/openapi.#{surface}.yml")`
- grep for any other `public/openapi` reference (CI workflow, docs, ADRs) and update it

`git mv` the three files so history follows. This keeps Committee, Minitest, Redocly, CI, and
Swagger UI on one source of truth — no Swagger-specific copy.

### 3b. rswag-api

`config/initializers/rswag_api.rb`:

```ruby
if Rails.env.development?
  Rswag::Api.configure do |c|
    c.openapi_root = Rails.root.join("openapi/bundled").to_s
    # Same fail-closed Rack::Auth::Basic block as every other tool host.
    Rswag::Api::Engine.middleware.use(Rack::Auth::Basic, "Swagger") { |u, p| ... }
  end
end
```

The document endpoint is thereby **authenticated**, on the swagger host only. `openapi_root` points
outside `public/`, so there is no second unauthenticated path to the same bytes.

### 3c. rswag-ui

`config/initializers/rswag_ui.rb` — `config_object` is a free-form hash that rswag-ui serialises
straight into the `SwaggerUIBundle({...})` call, so every required restriction is expressible:

```ruby
Rswag::Ui.configure do |c|
  c.openapi_endpoint "/openapi.app.yml", "Umaxica app surface"
  c.openapi_endpoint "/openapi.com.yml", "Umaxica com surface"
  c.openapi_endpoint "/openapi.org.yml", "Umaxica org surface"

  c.config_object[:supportedSubmitMethods] = []   # Try it out disabled
  c.config_object[:persistAuthorization]   = false
  c.config_object[:queryConfigEnabled]     = false
  c.config_object[:validatorUrl]           = nil  # no upload to validator.swagger.io
  c.config_object[:urls] # set only by openapi_endpoint above — no external documents
end
```

Do **not** use rswag-ui's own `basic_auth_enabled` / `basic_auth_credentials`: those put the
password into `config_object`, which is rendered into the page. Use the repository's
`Rack::Auth::Basic` pattern on `Rswag::Ui::Engine.middleware` instead, exactly as PgHero and Blazer
do.

No change to `config/initializers/cors.rb`, `content_security_policy.rb`, CSRF settings, or any API
authorization. If the Swagger UI page needs a CSP allowance, add it scoped to the swagger host only
— never by relaxing a shared policy.

### 3d. Routes

`config/routes/swagger.rb`:

```ruby
constraints host: [ENV["PUBLIC_SWAGGER_URL"], ENV["PRIVATE_SWAGGER_URL"],
                   "swagger.core.dev.localhost",].compact do
  if defined?(Rswag::Ui::Engine)
    mount Rswag::Api::Engine => "/", :as => :rswag_api
    mount Rswag::Ui::Engine  => "/", :as => :rswag_ui
  end
end
```

Both engines at `/` on the same host; confirm in the container that the UI mount does not shadow the
API document paths, and swap to distinct prefixes (`/` and `/openapi`) if it does — adjusting
`openapi_endpoint` to match.

**Verify in the container:** whether rswag-ui 2.17 vendors swagger-ui-dist inside the gem (2.x
historically did) or expects `node_modules/swagger-ui-dist`. If the latter, add `swagger-ui-dist` to
`package.json` devDependencies.

## Step 4 — rails_performance

### The self-mount problem (the main risk in this plan)

The gem's `config/routes.rb` ends with an unguarded, unconstrained:

```ruby
Rails.application.routes.draw do
  mount RailsPerformance::Engine => RailsPerformance.mount_at, :as => "rails_performance"
rescue ArgumentError
end
```

There is no disable flag. Left alone, `/rails/performance` is reachable on **every** host — the
exact leak section 2 of the request forbids, and an unreviewed mount that
`mounted_engine_invariant_test.rb` would fail on.

**Approach:** clear the engine's routing path before `add_routing_paths` collects it, then draw both
halves explicitly. In `config/application.rb`, immediately after `require "rails_performance"`:

```ruby
# The gem's config/routes.rb draws the engine's own routes AND mounts the engine into the
# application route set at RailsPerformance.mount_at, on every host, with no flag to turn that
# off. Dropping the routing path suppresses both; config/routes/performance.rb then draws the
# engine's routes and mounts it behind the host constraint.
RailsPerformance::Engine.paths["config/routes.rb"] = []
```

`config/routes/performance.rb` then draws the thirteen engine routes into
`RailsPerformance::Engine.routes` and mounts the engine under the host constraint.

**This duplicates a gem-internal route list, which will drift on upgrade.** Guard it: a test that
reads the gem's shipped `config/routes.rb` off disk
(`Gem.loaded_specs["rails_performance"].gem_dir`) and asserts the set of paths it declares equals
the set this repository draws, failing on any upgrade that adds or renames a route.

If clearing `paths["config/routes.rb"]` turns out not to work against Rails main, the fallback is to
accept the gem's mount and pin `RailsPerformance.mount_at`, with `verify_access_proc` failing closed
on any host but the performance host — **and** the invariant test updated to record that mount as
reviewed. Decide in the container; report which path was taken.

### Configuration

`config/initializers/rails_performance.rb`, entirely inside `if Rails.env.development?`:

- `config.redis = Redis.new(url: ENV.fetch("OBSERVABILITY_REDIS_URL"), driver: :hiredis)`
- `config.duration = 4.hours` — confirm against the gem source how retention is actually implemented
  (per-key TTL vs. a trim), and record the finding; adjust if 4h implies unbounded key growth
- `config.enabled = ENV.fetch("RAILS_PERFORMANCE_ENABLED", "true") == "true"` — the repo's
  established boolean-toggle idiom (`ENV.fetch("OPEN_TELEMETRY", "false") == "true"`)
- `config.mount_at` — set, but inert once the self-mount is suppressed
- `config.include_rake_tasks = false`; leave Sidekiq/Delayed Job/Grape off. Solid Queue is
  explicitly out of scope
- `config.custom_data_proc` — **do not set.** Its documented example reads the current user's email
- `config.ignored_paths` — add the three tool hosts' own paths so the dashboards do not measure
  themselves

**Secret handling.** `filter_parameters` alone is not assumed sufficient. Explicitly audit, in the
container, what the gem persists per request: path, query string, controller/action, format, status,
durations, and `custom_data`. If the raw query string is stored, add a redaction step reusing
`ObservabilityRedactor` (`lib/observability_redactor.rb`), which the Sentry initializer already uses
for exactly this. Back the audit with a test that drives a request carrying
`?access_token=…&password=…` and asserts neither value appears in any key under the
`rails_performance:` namespace. **Do not ship without running that test.**

**Failure isolation.** The gem's middleware must not turn a Valkey outage into a 500. Verify whether
it rescues `Redis::BaseError` itself; if it does not, wrap the recording call and log
`JitLogEvent.format("valkey.store.unavailable", store: "rails_performance", …)` — the same shape and
the same deliberate omission of the exception message (URLs can embed credentials) as the cache and
rate-limit error handlers in `config/environments/development.rb`. Never a bare `rescue nil`.

## Step 5 — Coverband

`config/initializers/coverband.rb`, inside `if Rails.env.development?`:

```ruby
Coverband.configure do |config|
  config.store = Coverband::Adapters::HashRedisStore.new(
    Redis.new(url: ENV.fetch("OBSERVABILITY_REDIS_URL"), driver: :hiredis),
    redis_namespace: "coverband",
  )
  config.background_reporting_enabled = ENV.fetch("COVERBAND_ENABLED", "true") == "true"
  config.use_oneshot_lines_coverage = true   # if the version supports it — verify
  config.track_views = false
  config.verbose = false
end
```

- **SimpleCov separation.** Untouched: `.simplecov` and its thresholds are not edited, and
  `coverband` is absent from the test group, so no Coverband measurement or reporting thread starts
  under Minitest. The two tools keep distinct jobs — SimpleCov measures test coverage, Coverband
  measures runtime execution.
- **One-shot.** Prefer `use_oneshot_lines_coverage` if the version supports it. It records _whether_
  a line ran and **not how many times** — record that property explicitly in the ADR, since it
  changes what the dashboard can answer.
- **Processes.** Enable under Puma (including `on_worker_boot` re-establishment after fork, which
  Coverband documents). Do **not** enable for Rails console, rake tasks, or Solid Queue workers.
  Gate on the process kind rather than assuming the initializer only runs under the web server.
- **Mutation.** Coverband's web reporter exposes clear/reset actions. Disable them
  (`config.web_enable_clear = false`) so the initial surface is read-only; Basic Auth is the second
  layer, not the only one. No mechanism that deletes "unused" code is built — not now, not later.

`config/routes/coverband.rb` mounts `Coverband::Reporters::Web.new` (a Rack app, so the
Flipper-style inline mount is the closer model) behind the host constraint, with the fail-closed
`Rack::Auth::Basic` wrapper.

## Step 6 — Registry, hosts, invariant test

- `app/values/fqdn_availability_registry.rb`: three new slots (`performance`, `coverband`,
  `swagger`) following the `pghero:` lambda shape exactly.
- `config/environments/development.rb`: six new `env_host_keys` entries and six new
  `localhost_tunnel_hosts` entries (`:3000` and `:3001` for each).
- `test/security/invariants/mounted_engine_invariant_test.rb`:
  - `UNAUTHENTICATED_ENGINE_CONSTANTS` += `Coverband`, `RailsPerformance`, `Rswag`
  - `FORBIDDEN_MOUNT_PATHS` += `/rails/performance`, `/coverband`
  - `REVIEWED_MOUNTS` += the three new host-scoped entries with their guard class
  - **and**, per the request, a new test per surface that actually exercises the guard — modelled on
    the existing "Flipper UI guard denies access when credentials are not configured" test, which
    constructs the guard and asserts 401. Adding a name to `REVIEWED_MOUNTS` is not sufficient.

## Step 7 — Tests

New: `test/integration/{performance,coverband,swagger}_surface_test.rb`, modelled closely on
`test/integration/flipper_ui_surface_test.rb` (which already has the `basic_auth_headers` helper and
the `with_…_credentials` stub of `Rails.app.creds`).

Because these gems are development-only, an integration test cannot drive the real engines under
`RAILS_ENV=test`. Split accordingly:

- **Runs in the test suite (no gem needed):** route-set assertions via
  `Rails.application.routes.recognize_path(path, host:)` — reachable on the right host, raising
  `ActionController::RoutingError` on every wrong one (coverband path from the swagger host, etc.);
  the guard-returns-401 unit tests; `Host` Authorization contract assertions extending
  `test/config/host_authorization_contract_test.rb`, including that no bare `*.umaxica.dev` wildcard
  is admitted and that `config.hosts` entries are exact strings; `FqdnAvailabilityRegistry` drift;
  the rails_performance route-list drift guard; and a test that `Coverband` is not defined under
  `RAILS_ENV=test`.
- **Runs in the container against a booted development app, recorded as manual evidence:** Swagger
  UI renders; the OpenAPI document is fetched from the swagger host with credentials and 401s
  without; `supportedSubmitMethods: []` and `validatorUrl: null` are present in the served HTML; no
  request leaves for `validator.swagger.io` (check via the browser network panel); the
  rails_performance secret-leak test above; Valkey-down behaviour for both tools.

Also add a forbidden-pattern style check that `public/openapi` appears nowhere after the move.

## Step 8 — Documentation

- New `adr/diagnostic-surfaces-performance-coverband-swagger.md`: the three FQDNs, each tool's
  purpose, Cloudflare Tunnel as the transport with Cloudflare configuration owned elsewhere, the
  host-constraint and Basic-Auth model, Valkey DB 6 and the two namespaces, retention, the
  per-feature ENV toggles, the SimpleCov/Coverband split, the Committee/Swagger shared source of
  truth, and **the development-only limitation and what it costs**.
- New `adr/openapi-bundle-outside-public.md` (or an amendment to the api-versioning ADR) for the
  `public/` → `openapi/bundled/` move.
- Amend `adr/valkey-nonprod-logical-db-topology.md` with DB 6/7.
- `evidence/2026-09-17-diagnostic-surfaces-host-isolation.md` — written **after** the container run,
  recording only checks actually performed, and recording the unrun ones as unrun.

## Commits

One logical unit each, local only — no push, no PR, no issue changes. The existing uncommitted work
(`.devcontainer/*`, `config/database.yml`, the E1 replay test/notes/evidence) must be preserved
untouched; stage only this plan's paths.

1. `openapi: move bundled descriptions out of public/`
2. `valkey: add observability responsibility (DB 6/7)`
3. `swagger: mount rswag-ui/rswag-api on swagger.umaxica.dev`
4. `performance: mount rails_performance on performance.umaxica.dev`
5. `coverband: mount Coverband reporter on coverband.umaxica.dev`
6. `security: extend mounted-engine and host invariants to the three new surfaces`
7. `docs: record the diagnostic surface decisions`

## Verification

In this session (static only): `bundle lock` resolves; `bun run openapi:verify` passes after the
move (bun is available on the host); a grep shows no remaining `public/openapi` reference.

In the container, on next build — the checks this plan's completion report must cover, and which
**cannot** be run here:

```bash
bin/rails test test/security/invariants/mounted_engine_invariant_test.rb
bin/rails test test/config/host_authorization_contract_test.rb
bin/rails test test/integration/performance_surface_test.rb \
               test/integration/coverband_surface_test.rb \
               test/integration/swagger_surface_test.rb
bin/rails test test/contracts/            # OpenAPI move did not break Committee
bin/rails test                            # full suite
bun run check
```

Then, against the running development app: reach each of the three hosts through the tunnel, confirm
401 without credentials and 200 with, confirm each dashboard is unreachable from the other two hosts
and from `www.umaxica.app`, confirm generated links stay on the canonical origin with no `:3000` or
`localhost` leaking in, and confirm no redirect loop.

For section 13 (before/after latency, memory, Valkey ops): measurable only in the container. With
development-only gems the production request path is unchanged by construction, but that is an
argument, not a measurement — report it as such, and take the development-side measurement with
`derailed_benchmarks`/`rack-mini-profiler`, both already in the Gemfile.

## Rollback / disable

| Scope                  | How                                                                                                                |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------ |
| One feature, no deploy | `RAILS_PERFORMANCE_ENABLED=false`, `COVERBAND_ENABLED=false`, or unset `PUBLIC_/PRIVATE_SWAGGER_URL`               |
| One feature, code      | Delete its `config/routes/<tool>.rb`, its initializer, its `draw` line, its registry slot, and its `Gemfile` entry |
| Everything             | Revert commits 3–7; commits 1–2 are independent and can stay                                                       |

Unsetting a host's `PUBLIC_*`/`PRIVATE_*` pair drops it from both the route constraint and
`config.hosts`, leaving only the `.core.dev.localhost` alias — so a partial disable degrades toward
less exposure, not more.
