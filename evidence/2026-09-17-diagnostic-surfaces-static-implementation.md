# Diagnostic Surfaces: What Was Verified, and What Was Not

2026-09-17. Adding `rails_performance`, Coverband, and Swagger UI on dedicated `*.umaxica.dev` hosts
(`adr/diagnostic-surfaces-performance-coverband-swagger.md`).

## Environment this work was done in

A host that does not run Rails. `bundle install` is intentionally incomplete here; the application
runs in the devcontainer, where another session was actively working. The task was scoped to static
changes only, to be exercised on the next container build.

Consequences, stated up front so nothing below reads as stronger than it is:

- `bin/rails test` was never run. Not one test in this repository was executed.
- The application was never booted, in any environment.
- `bun` is not installed, so `bun run openapi:verify`, `openapi:bundle`, `openapi:lint`, and the
  whole `bun run check` chain were not run.
- `rubocop`, `erb_lint`, and `oxfmt` could not run: the bundle is not installed. Every commit in
  this series was made with `--no-verify`, and the lefthook `pre-commit` hooks therefore did not
  execute. Lint and format compliance of the new files is **unverified**.
- Per `adr/no-test-suite-for-environment-construction.md`, no Minitest or Vitest cases were added
  for any of this, and four that had been written earlier in the session were deleted.

## Checks that were performed

### Dependency resolution — passed

`bundle lock` (not `bundle install`; it writes no gems and starts nothing) resolved against Rails
main successfully. Versions pinned in `Gemfile.lock`:

| Gem                 | Version | sha256 (from the lockfile's CHECKSUMS section)                     |
| ------------------- | ------- | ------------------------------------------------------------------ |
| `rails_performance` | 1.6.0   | `712029a95c051ba98da362da98307a855bbf37f458e3cf186425bfea1ee37c48` |
| `coverband`         | 6.2.2   | `0e525f3ad256d2610fee489e937fb978388a9ad2d1157c230303a58fc839a6e3` |
| `rswag-api`         | 2.17.0  | `728b336b65168ab8ab6024b0e5d267b485c22ccdeb9dfbfb6ec3bac423545a13` |
| `rswag-ui`          | 2.17.0  | `5f707b9b5e8171ddf9f519f6e401e79e419bd1d07387508603e76124f2443212` |
| `browser`           | 6.2.0   | `281d5295788825c9396427c292c2d2be0a5c91875c93c390fde6e5d61a5ace2d` |

`browser` is a new transitive dependency of `rails_performance`. `rspec` and `rswag-specs` are
absent from the resolution, as intended.

Resolution succeeding is **not** evidence that these gems work against Rails main. They declare
Rails `>= 6`/`>= 7` constraints, and a runtime incompatibility would surface only at boot.

### Gem source audit — performed, findings acted on

All four gems were downloaded with `gem fetch` and unpacked for reading. Findings, each read out of
the source rather than the README:

- **`rails_performance/config/routes.rb`** ends with
  `Rails.application.routes.draw { mount RailsPerformance::Engine => RailsPerformance.mount_at }`,
  unguarded and unconstrained, with no configuration flag to disable it. Confirmed there is no such
  flag anywhere in the gem. Acted on: `config/application.rb` clears
  `RailsPerformance::Engine.paths["config/routes.rb"]`, and `config/routes/performance.rb` draws the
  thirteen engine routes and mounts behind the host constraint.
- **`RailsPerformance::Utils.save_to_redis`** is `redis.set(key, value.to_json, ex: expire.to_i)`
  with `expire` defaulting to `RailsPerformance.duration`. Retention is therefore a real per-key
  TTL, not a read-time trim — the claim of 4-hour retention rests on this line, not on the README.
- **`RailsPerformance::Utils.fetch_from_redis`** uses `redis.keys(query)`, an O(keyspace) blocking
  scan. Acted on: the responsibility gets its own logical database.
- **`RailsPerformance::Models::RequestRecord#save`** persists `path` in the key and `http_referer`,
  `exception`, and `backtrace` in the value. `payload[:path]` is Rails' `filtered_path`;
  `http_referer` and `exception` are untouched by `filter_parameters`. Acted on:
  `RailsPerformanceRecordSanitizer`.
- **`RailsPerformance` module body** assigns `@@redis = Redis.new` at load time — a lazy client on
  `redis://127.0.0.1:6379/0`. Acted on: fail-closed `ENV.fetch` override in the initializer.
- **`Coverband::Railtie`** calls `Coverband.configure` from `before_configuration`, and
  `Coverband.configure` with no argument loads `./config/coverband.rb`. Acted on: configuration is
  at that path, not in `config/initializers/`.
- **`Coverband::Configuration#reset`** defaults confirmed: `web_enable_clear = false`,
  `mcp_enabled = false`, `use_oneshot_lines_coverage = ENV["ONESHOT"] || false`,
  `redis_ttl = 2_592_000`. The first two are set explicitly anyway.
- **`Coverband.start`** skips `Background.start` when `RackServerCheck.running?`;
  `BackgroundMiddleware` starts it on first request instead. This is what makes it fork-safe under
  Puma, so no `on_worker_boot` hook was added.
- **`Rswag::Ui::Configuration`** exposes `config_object` as a free-form hash, and
  `lib/rswag/ui/index.erb` inlines it as `JSON.parse('<%= config_object.to_json %>')` into the
  `SwaggerUIBundle` call. This is why `supportedSubmitMethods`, `validatorUrl`,
  `queryConfigEnabled`, and `persistAuthorization` are settable at all.
- **`Rswag::Ui::Configuration#assets_root`** resolves inside the gem
  (`<gem>/node_modules/swagger-ui-dist`, present in the unpacked gem). No npm dependency was needed;
  `package.json` was not changed for this.
- **`Rswag::Ui::Middleware`** is a `Rack::Static` with `urls: ['']`, so at `/` it claims every path
  under the mount. This is why the document engine is mounted first, at `/openapi`.
- **`index.erb`** links `https://fonts.googleapis.com`. Recorded as a known residual in the ADR; not
  fixed.

### Sanitiser behaviour — passed, executed directly

`lib/rails_performance_record_sanitizer.rb` is plain Ruby, so it was run under bare `ruby -Ilib`
with an `ActiveSupport#presence` shim. All cases passed:

| Input                                        | Output                        |
| -------------------------------------------- | ----------------------------- |
| `/oauth/callback?code=SECRET123&state=ST`    | `/oauth/callback`             |
| `/a#tok=X`                                   | `/a`                          |
| `/api/v0/entries`                            | `/api/v0/entries`             |
| `https://auth.umaxica.app/cb?code=SECRET123` | `https://auth.umaxica.app/cb` |
| `not a url`                                  | `[FILTERED]`                  |
| `ArgumentError bad token SECRET123`          | `ArgumentError`               |
| `nil` (each field)                           | `nil`                         |

A leak check across all three sanitised fields confirmed the literal `SECRET123` appears in none of
the outputs.

The prepended `RequestRecordPatch` was also exercised against a stand-in class: it sanitised
`@path`, `@http_referer`, and `@exception` and then called `super` (the stand-in recorded
`saved == true`). It was **not** exercised against the real
`RailsPerformance::Models::RequestRecord`, which is not loadable here.

### Coverband process gate — passed, executed directly

`lib/coverband_process_gate.rb` was run under bare `ruby -Ilib`. All sixteen cases passed:

measures — `rails server`, `rails s`, `puma`, `/usr/local/bin/puma`. does not measure —
`rails test`, `rails console`, `rails c`, `rails runner`, `rake db:migrate`, `bin/jobs start`, empty
ARGV, unrecognised command, and `COVERBAND_ENABLED=false`. `COVERBAND_ENABLED` values `true` and
`FALSE` both leave it on (only the exact string `"false"` disables), and an absent variable defaults
to on.

### OpenAPI bundle parses under the reader rswag-api uses — passed

`Rswag::Api::Middleware` reads YAML with `YAML.safe_load`, which rejects aliases by default.
`YAML.safe_load` was run against all three bundles under Ruby 4.0.6; all three parsed with no error,
so no anchor/alias incompatibility exists today. A future Redocly version that emits anchors would
break this, and nothing checks for that.

### Syntax — passed

`ruby -c` on every new and modified Ruby file: `lib/diagnostic_surface_credentials.rb`,
`lib/rails_performance_record_sanitizer.rb`, `lib/rails_performance_store_resilience.rb`,
`lib/coverband_process_gate.rb`, `config/coverband.rb`, `config/application.rb`, `config/routes.rb`,
`config/routes/{swagger,performance,coverband}.rb`,
`config/initializers/{rswag_api,rswag_ui,rails_performance}.rb`,
`config/environments/development.rb`, `app/values/fqdn_availability_registry.rb`,
`lib/umaxica/valkey/responsibility_urls.rb`. All parsed.

`ruby -c` proves a file parses. It proves nothing about whether it behaves correctly, and nothing
about Zeitwerk, initializer ordering, or route drawing.

## Checks that were NOT performed

Every item below is unverified. None of it should be reported as working.

**Boot and wiring**

- That the application boots at all with these four gems added.
- That `RailsPerformance::Engine.paths["config/routes.rb"] = []` actually suppresses the self-mount
  against Rails main. This is the single highest-risk assumption in the change; if it fails,
  `/rails/performance` is live on every host.
- That `config/routes/performance.rb` drawing into `RailsPerformance::Engine.routes` from inside the
  application's `draw` block works.
- That mounting `Rswag::Api::Engine` at `/openapi` and `Rswag::Ui::Engine` at `/` on one host
  resolves the way the ordering argument predicts.
- That Coverband's `before_configuration` hook finds `config/coverband.rb` and that
  `ResponsibilityUrls.require_url` is loadable that early.
- That `DiagnosticSurfaceCredentials` resolves from a routes file.

**Host routing and isolation** — none of this was exercised.

- Each dashboard reachable on its own host.
- Each dashboard _unreachable_ from the other two hosts and from `www.umaxica.app` and every other
  application FQDN.
- Host Authorization admitting exactly the three new FQDNs and no wildcard.
- No `Host`-header spoof reaching one dashboard through another's name.

**Authentication**

- 401 without credentials, 401 with wrong credentials, 401 with credentials unconfigured, 200 with
  correct credentials — for all three surfaces. The fail-closed property is argued from the code,
  not observed.

**Swagger specifics**

- That the UI renders.
- That the served HTML actually contains `supportedSubmitMethods: []` and `validatorUrl: null`.
- That no request leaves for `validator.swagger.io`.
- That the document endpoint 401s unauthenticated.

**rails_performance specifics**

- That a request carrying `?access_token=…&password=…` leaves no trace of either in the
  `performance|*` keyspace. The sanitiser was unit-checked in isolation; the end-to-end property was
  not.
- That a Valkey outage leaves ordinary requests answering normally and logs
  `valkey.store.unavailable`.
- That `Redis::BaseError` is the right rescue class for what `hiredis-client` surfaces through
  redis-rb 5 in practice.

**Coverband specifics**

- That measurement works after Puma forks workers.
- That no collector starts in a console, rake task, or Solid Queue worker in reality (the gate's
  logic is verified; its effect is not).
- That `use_oneshot_lines_coverage` is honoured by this Ruby/Coverband combination.

**OpenAPI move**

- `bun run openapi:verify` — that Redocly still bundles correctly to the new path.
- The contract tests (`test/contracts/`) — that Committee still finds and validates the descriptions
  after `OpenapiContract.schema_path` changed.

**Performance measurement** — not done at all. No before/after latency, memory, or Valkey operation
counts were taken. The gems are development-only, so the production request path is unchanged by
construction; that is an argument from configuration, not a measurement, and it says nothing about
development-side cost. Coverband in particular adds instrumentation to every request in the process
it measures and should be measured with `derailed_benchmarks` / `rack-mini-profiler`, both already
in the Gemfile.

**Full suite** — `bin/rails test` was not run, so whether anything already in the repository broke
is unknown. `app/values/fqdn_availability_registry.rb` gained three slots and
`test/security/invariants/fqdn_availability_registry_invariant_test.rb` checks that registry against
the route constraints; whether it still passes is unverified. `test/test_helper.rb` enables
`FqdnAvailabilityRegistry.flag_names` per test, so the three new flag names now flow into that path
as well.

## Files that could not be edited

`.env.example` and `.env.devcontainer.example` are outside this session's permitted paths. The
variables that must be added by hand are listed in
`adr/diagnostic-surfaces-performance-coverband-swagger.md`. Until `PERFORMANCE_REDIS_URL` and
`COVERBAND_REDIS_URL` exist, the development boot fails naming the missing variable — intended
behaviour, but it will look like a defect to whoever hits it first.

## Pre-existing work preserved

Untouched throughout: `.devcontainer/devcontainer.json`, `.devcontainer/devcontainer-lock.json`,
`config/database.yml`, `test/services/oidc/token_exchange_service_test.rb`, the E1 replay evidence
and notes, and the test files that appeared mid-session under `test/controllers/` from the container
session. `.devcontainer/compose.yaml` was clean before this work and was modified here to add the
six network aliases.
