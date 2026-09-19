# Diagnostic Surfaces: rails_performance, Coverband, Swagger UI

Accepted: 2026-09-17

## Context

This application already runs four operator dashboards, each on its own dedicated `*.umaxica.dev`
host reached through Cloudflare Tunnel: Mission Control Jobs, Flipper UI, Blazer, and PgHero. Three
questions had no surface:

- how long requests take, broken down by controller and action
- which Ruby code actually executes
- what the JSON API contract says, in a form a person can read

Cloudflare Tunnel, DNS, and Access configuration are managed outside this repository and were not
touched. This ADR covers only what Rails does.

## Decision

Three more dashboards, each following the existing pattern rather than introducing a new one.

| Surface           | Canonical origin                  | Development alias                | Purpose                                                                                  |
| ----------------- | --------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------- |
| rails_performance | `https://performance.umaxica.dev` | `performance.core.dev.localhost` | request latency, per-controller/action breakdown, percentiles, throughput, DB/view split |
| Coverband         | `https://coverband.umaxica.dev`   | `coverband.core.dev.localhost`   | which Ruby lines executed                                                                |
| Swagger UI        | `https://swagger.umaxica.dev`     | `swagger.core.dev.localhost`     | renders the bundled OpenAPI descriptions                                                 |

The original request named `performace.umaxica.dev`. That was confirmed as a typo and corrected to
`performance.umaxica.dev`; the Cloudflare DNS record must be created with the corrected spelling.

### The pattern each one follows

Established by `config/routes/pghero.rb` and `config/initializers/pghero.rb`:

1. `config/routes/<tool>.rb` — `constraints host:` over exact hostname strings, never a pattern,
   never a wildcard:
   `[ENV["PUBLIC_<TOOL>_URL"], ENV["PRIVATE_<TOOL>_URL"], "<tool>.core.dev.localhost"].compact`.
2. A `defined?` guard, so the route is not drawn where the gem is absent.
3. Fail-closed `Rack::Auth::Basic` with `ActiveSupport::SecurityUtils.secure_compare` and a
   non-short-circuiting `&`, credentials read through `Rails.app.creds.option`. Unset credentials
   mean 401, never open access.
4. An `FqdnAvailabilityRegistry` slot, which an existing invariant test checks against the route
   constraints.
5. `PUBLIC_`/`PRIVATE_` entries in development's `env_host_keys`, plus the `.core.dev.localhost`
   aliases at `:3000` and `:3001`.

`config/environments/production.rb` is untouched. Its `config.hosts` is a flat literal that lists no
`*.umaxica.dev` host at all, and these gems do not load outside development. No wildcard was
introduced anywhere; every entry is an exact FQDN, so a spoofed `Host` cannot reach one dashboard
through another's name.

Basic Auth is the origin's own control and does not depend on Cloudflare Access. Access fronts these
names, but a request arriving at the origin directly carries whatever `Host` header it likes, and a
mounted Rack app subclasses nothing of this application — `enforce_access_policy!`,
`FqdnAvailabilityGate`, surface isolation, and the per-surface CSRF configuration never run for it.

`DiagnosticSurfaceCredentials` holds the credential comparison the four new mount points would
otherwise repeat. The existing Flipper, Blazer, and PgHero mounts keep their inline copies:
rewriting working, tested authorization code is not part of adding new surfaces.

### Development only, and what that costs

All three gems are `group :development`, matching `pghero`, `blazer`, and `rails_db`.

For Swagger UI and the performance dashboard this is a straightforward scope decision. For Coverband
it is a real departure from the tool's purpose: Coverband exists to tell you which code runs _in
production_, and confined to development it reports which code runs while developers work. That is a
much weaker signal, and it is recorded here rather than glossed. Promoting it to
`group :development, :production` is a separate decision that must also revisit
`test/security/invariants/mounted_engine_invariant_test.rb`, which asserts that unauthenticated-by-
default engines are not loadable outside development.

### Storage

Two new Valkey responsibilities in `lib/umaxica/valkey/responsibility_urls.rb`, each on its own
logical database (development 12/13, test 14/15) rather than sharing one behind key prefixes:

| Responsibility | Variable                | Dev DB | Namespace                               |
| -------------- | ----------------------- | ------ | --------------------------------------- |
| `performance`  | `PERFORMANCE_REDIS_URL` | 12     | `performance\|…` (gem's own key format) |
| `coverband`    | `COVERBAND_REDIS_URL`   | 13     | `coverband`                             |

Separate databases, not just namespaces, because `rails_performance` reads with
`redis.keys("performance|*")` — an O(keyspace) blocking scan. Confined to its own database, a
dashboard query cannot stall the cache, the rate-limit counters, or auth state. It also keeps a
development `FLUSHDB` scoped to the dashboard being triaged.

Both resolve through `ResponsibilityUrls.require_url`, which uses one-argument `ENV.fetch`. This is
load-bearing: handed no URL, both gems default to `redis://127.0.0.1:6379/0` — logical database 0,
the application cache. A missing variable would therefore not fail, it would quietly write
observability data into `Rails.cache`, and nothing downstream would report it.

The test databases are declared even though nothing connects to them under `RAILS_ENV=test`:
`assert_nonprod_db!` refuses to validate a responsibility it has no expected database for. They are
deliberately absent from `Umaxica::Valkey::TestTarget::URL_NAMES`, so test boot does not demand
variables it will never use.

### Retention

`rails_performance` writes every record with `redis.set(key, value, ex: RailsPerformance.duration)`
— confirmed in `RailsPerformance::Utils.save_to_redis`, not assumed. `duration` is four hours, so
this is a real per-key TTL: each record expires four hours after it is written and the keyspace
cannot grow without bound. The cost model is one key per request plus one trace key.

Coverband's `HashRedisStore` keeps one hash per file rather than one key per line, so its key count
is a function of the repository, not of traffic.

### What rails_performance must not store

`config.filter_parameters` is not sufficient here and is not assumed to be. Of the three free-text
fields `RequestRecord#save` persists it covers one, partially:

- **`path`** — Rails sets it from `request.filtered_path`, so only parameter names on the filter
  list are redacted. A one-off debug parameter, a vendor callback's own naming, or a secret in a
  path segment is not.
- **`http_referer`** — stored verbatim on 404s. `filter_parameters` never touches it, and a Referer
  carries the referring page's entire query string, which for an authorization redirect is where the
  code, state, and token live.
- **`exception`** — `[class, message]` joined. Exception messages quote the values that caused them.

`RailsPerformanceRecordSanitizer` is prepended to `RequestRecord` and handles each explicitly, on
the way _into_ Valkey. Redacting at read time would leave the secret sitting in the store, where
`redis.keys` and any operator connection still find it.

- `path` — query string and fragment removed entirely, not filtered. The dashboard aggregates by
  `controller#action` and needs none of it, and "no query string is stored" stays true as parameter
  names change, which "every sensitive name is on the filter list" does not. It also keeps `|` out
  of a `|`-delimited record key.
- `http_referer` — reduced to `scheme://host/path` by `ObservabilityRedactor.scrub_url`, the same
  treatment `config/initializers/sentry.rb` gives a referring URL.
- `exception` — class name only.

The backtrace stored alongside them is left alone: file paths and line numbers from this repository
and its gems.

`custom_data_proc` is left `nil`. The gem's documented example for that hook reads the signed-in
user's email address out of the request env.

### Observability failure must not become application failure

`rails_performance` records a request _after_ the application has produced its response, and
`Utils.save_to_redis` calls `redis.set` bare — so a Valkey outage turned a correctly answered
request into a 500. `RailsPerformanceStoreResilience` prepends the singleton method, which is the
single write chokepoint for every record type the gem persists.

The failure is not swallowed. It is logged through `JitLogEvent.format` under
`valkey.store.unavailable`, the same event name and shape the cache and rate-limit error handlers in
`config/environments/*` use, with the exception class kept and the message omitted because store
URLs can embed credentials.

Reads are deliberately left to raise. `fetch_from_redis` only runs while someone is looking at the
dashboard, and a dashboard that renders empty during an outage is worse than one that fails visibly:
the empty page reads as "no traffic".

Coverband's own railtie already rescues `Redis::CannotConnectError` at boot and logs rather than
failing, and its reporting happens on a background thread rather than on the request path.

### Which processes Coverband measures

`require "coverband"` is what starts it — the railtie hooks `before_configuration`, which fires on
the `class Application < Rails::Application` line, and calls `Coverband.configure` (loading
`config/coverband.rb`) followed by `Coverband.start`. Not requiring it is therefore the off switch,
and `CoverbandProcessGate` decides.

It is an **allowlist**: only the process serving requests measures. `bin/rails server` and a
directly booted `puma` do; a console, a `rake` task, `bin/jobs`, `rails runner`, the test suite, and
anything unrecognised do not. A denylist would silently begin measuring in whatever process type is
added next, and a dataset polluted that way is wrong in a way the dashboard cannot show.

Fork safety is the gem's own design and is not re-implemented: `Coverband.start` skips the
background reporter when `RackServerCheck.running?`, and `BackgroundMiddleware` starts it on each
process's first request instead — under Puma, after the workers fork.

Configuration must live at `config/coverband.rb` exactly. `config/initializers/*` is read long after
`before_configuration`, so configuration placed there would apply after the collector had already
started on gem defaults, including a Redis client pointed at localhost.

### One-shot coverage, and what it cannot answer

`use_oneshot_lines_coverage = true`. Ruby stops counting a line after its first execution, which is
what makes this affordable on a request path at all.

The trade is that **execution counts are never collected, not merely unreported**. The data answers
"did this line ever run" and nothing else. Coverband can never rank hot code or answer a performance
question; that is the performance dashboard's job. This is stated here because it changes what the
surface can be asked.

### Coverband is read-only

`web_enable_clear = false` (already the default, stated because the clear action wipes the entire
dataset and a default is not where a destructive capability should rest). `hide_settings = true`, so
the UI does not render resolved configuration — one gem change away from rendering a store URL that
can carry credentials. `mcp_enabled = false`: Coverband 6.2 ships an MCP server that answers
coverage queries over its own protocol, outside this application's host constraints and Basic Auth
entirely.

**No mechanism that deletes code Coverband reports as unexecuted is built here, and none should
be.**

### Coverband and SimpleCov do different jobs

SimpleCov measures test coverage and is untouched: `.simplecov` and every threshold in it are
unchanged. Coverband is absent from the test group, so no collector and no reporting thread start
under Minitest, and `CoverbandProcessGate` refuses `rails test` independently of that.

### Swagger

`rswag-ui` and `rswag-api` only. `rswag-specs` and RSpec are not added: contract testing stays
Minitest plus Committee against the same descriptions (`test/support/openapi_contract.rb`).

The descriptions are the existing ones. `openapi/` remains the source tree, Redocly bundles it, and
the bundle is what Committee validates against and what Swagger UI renders. No Swagger-specific copy
exists. The per-surface split (app / com / org) is preserved.

The bundle moved from `public/` to `openapi/bundled/` — see `adr/openapi-bundle-outside-public.md`.

Two mounts on separate paths, in this order, because `Rswag::Ui::Middleware` is a `Rack::Static`
built with `urls: ['']` and at `/` would answer before the document endpoint ran:

```
mount Rswag::Api::Engine => "/openapi"   # the descriptions
mount Rswag::Ui::Engine  => "/"          # the UI
```

Both are guarded independently. The descriptions enumerate every internal JSON endpoint, its
parameters, and its response shapes; an unauthenticated document endpoint hands that inventory over
whether or not the UI reading it is protected.

Read-only, each restriction stated rather than left to a default:

| Setting                  | Value   | Why                                                                                             |
| ------------------------ | ------- | ----------------------------------------------------------------------------------------------- |
| `supportedSubmitMethods` | `[]`    | no "Try it out" for any method, so the page cannot drive requests into the app/org/com surfaces |
| `persistAuthorization`   | `false` | no credentials in browser storage                                                               |
| `queryConfigEnabled`     | `false` | `?url=…` cannot make the page load an arbitrary remote OpenAPI document                         |
| `validatorUrl`           | `nil`   | no POST of the description to `validator.swagger.io` on every page view                         |

The three endpoint URLs are relative paths under the same host, so they resolve through the
authenticated `/openapi` mount and nowhere else.

rswag-ui's own `basic_auth_enabled` / `basic_auth_credentials` are deliberately unused: they store
the password in `config_object`, which the gem serialises into the rendered HTML.

No CORS, CSP, CSRF, API authorization, or OAuth setting was relaxed to make any of this work.

**Known residual:** the gem's `index.erb` links a Google Fonts stylesheet, so the page makes one
external request for fonts. It carries no application data, and the surface is development-only
behind Basic Auth. Suppressing it means vendoring an override template at
`Rails.root/swagger/index.erb`; recorded rather than done.

### Enabling and disabling

Each surface is independently switchable.

| Surface           | Off switch                                         | Effect                                                                                       |
| ----------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| rails_performance | `RAILS_PERFORMANCE_ENABLED=false`                  | no recording, no Valkey connection; route stays drawn with no data                           |
| Coverband         | `COVERBAND_ENABLED=false`                          | gem never required: no collector, no reporting thread, no Valkey connection, route not drawn |
| Swagger           | unset `PUBLIC_SWAGGER_URL` / `PRIVATE_SWAGGER_URL` | host drops out of the route constraint and `config.hosts`                                    |

Only the exact string `"false"` disables Coverband, so a typo cannot silently turn observability
off. Unsetting a host's `PUBLIC_`/`PRIVATE_` pair degrades toward _less_ exposure, never more.

### Credentials

| Surface           | User                         | Password                     |
| ----------------- | ---------------------------- | ---------------------------- |
| rails_performance | `RAILS_PERFORMANCE_USERNAME` | `RAILS_PERFORMANCE_PASSWORD` |
| Coverband         | `COVERBAND_USERNAME`         | `COVERBAND_PASSWORD`         |
| Swagger           | `SWAGGER_USERNAME`           | `SWAGGER_PASSWORD`           |

Read through `Rails.app.creds.option`, the ENV-then-credentials lookup the other dashboards use.
Unset means 401.

### Environment variables to add

`.env.example` and `.env.devcontainer.example` were not edited by the session that made this change:
a global permission rule (`Read(**/.env*)`) denies agent access to every env file, and it was
respected rather than worked around. They must be updated by hand. `bin/setup-diagnostic-env`
appends the block below to both, idempotently.

```
PUBLIC_PERFORMANCE_URL=performance.umaxica.dev
PRIVATE_PERFORMANCE_URL=performance.core.dev.localhost
PUBLIC_COVERBAND_URL=coverband.umaxica.dev
PRIVATE_COVERBAND_URL=coverband.core.dev.localhost
PUBLIC_SWAGGER_URL=swagger.umaxica.dev
PRIVATE_SWAGGER_URL=swagger.core.dev.localhost

PERFORMANCE_REDIS_URL=redis://valkey:6379/12
COVERBAND_REDIS_URL=redis://valkey:6379/13

RAILS_PERFORMANCE_USERNAME=
RAILS_PERFORMANCE_PASSWORD=
COVERBAND_USERNAME=
COVERBAND_PASSWORD=
SWAGGER_USERNAME=
SWAGGER_PASSWORD=

# Optional. Both default to on; only the exact string "false" disables, so a typo
# cannot silently turn observability off.
RAILS_PERFORMANCE_ENABLED=true
COVERBAND_ENABLED=true
```

Sixteen variables: six hostnames, two Valkey URLs, six credentials, two toggles. The credentials are
read through `Rails.app.creds.option`, which checks ENV first and then Rails credentials, so a
deployment may supply them either way; left unset, the surface answers 401.

Until the Valkey URLs exist, the development boot fails naming the missing variable. That is the
intended behaviour, not a defect.

### rails_performance mounts itself, and that had to be stopped

The gem ships one `config/routes.rb` that draws the engine's route set and then calls
`Rails.application.routes.draw { mount RailsPerformance::Engine => RailsPerformance.mount_at }` with
no host constraint and no flag to disable it. Left alone, `/rails/performance` answers on **every**
FQDN this application serves.

The only available off switch is clearing the engine's `paths["config/routes.rb"]`, and it has to
happen in `config/application.rb` because `add_routing_paths` runs before `config/initializers/*`.
That suppresses the engine's own routes too, so `config/routes/performance.rb` carries a verbatim
copy of the gem's thirteen routes behind the host constraint.

That copy is a gem internal and **will drift on upgrade with nothing to flag it**. When bumping
`rails_performance`, diff its `config/routes.rb` against that block: a renamed route surfaces only
as a dashboard tab that 404s, and a new one simply never appears.

## Consequences

- Three more operator surfaces exist, each on an exact FQDN, each with an origin-side credential
  that fails closed, none of them reachable from an application surface.
- Coverband's answer is about development execution, which is not what Coverband is for.
- rails_performance's route list is a maintained copy of a gem internal.
- Development boot now requires two more Valkey URLs and, for any surface actually used, its
  credential pair.
- Per `adr/no-test-suite-for-environment-construction.md`, none of this is covered by Minitest or
  Vitest. Nothing here fails automatically if a gem moves out of `group :development` or the
  self-mount suppression is dropped. Verification is by running it and recording the result in
  `evidence/`.

## Related

- `adr/openapi-bundle-outside-public.md` — moving the bundle out of statically served `public/`
- `adr/no-test-suite-for-environment-construction.md` — why no tests accompany this
- `adr/valkey-nonprod-logical-db-topology.md` — the logical database layout extended here
- `adr/public-private-url-boundaries.md` — the `PUBLIC_`/`PRIVATE_` naming
- `docs/architecture/cloudflare-request-paths.md` — how a request reaches these hosts
