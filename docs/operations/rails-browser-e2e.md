# Rails browser E2E

`bun run test:e2e:rails` owns a real Puma server in `RAILS_ENV=test` and runs TypeScript Playwright
Test against the Auth app public Inertia/React landing in Chromium. It supplements Minitest,
Integration Test and Vitest. `bun run test:e2e` retains its existing meaning. No Capybara or Ruby
Playwright driver is involved. Existing tests include presentation fixtures and specialized
Secret/admission scenarios requiring externally supplied runners; this command neither reconfigures
nor runs those scenarios.

## First setup and dependencies

Use the Ruby/Bun versions and test credentials described in the repository README. Install the
existing locked dependencies and Chromium:

```bash
bundle install
bun install --frozen-lockfile
bun run test:e2e:rails --help
node node_modules/playwright/cli.js install --with-deps chromium
```

PostgreSQL and Valkey KVS must be running. Run inside the Dev Container: the PostgreSQL test target
is fixed in `config/database.yml` (`primary:5432`). Supply `VALKEY_KVS_HOST` and `VALKEY_KVS_PORT`
through the existing local contract. The KVS host must be `127.0.0.1`, `localhost`, or the canonical
local `valkey-kvs` service; remote KVS hosts are rejected before Rails initialization. Never use
production secrets or services. The bootstrap requires the dedicated
`config/credentials/test.yml.enc` and `config/credentials/test.key`, rejects a generic
`RAILS_MASTER_KEY` override, and uses a new synthetic cookie signing secret for each invocation.
Test cache is memory; KVS uses test DBs 4 and 6.

This command uses the ordinary `test_*` PostgreSQL databases in `config/database.yml`, prepared
through the [database workflow](db-workflow.md). It requires no isolated source fleet, manifest,
receipt or PostgreSQL run ID. Prepare current schemas and public-page reference data before running:

```bash
bun run test:e2e:rails
```

The runner acquires `tmp/parallel-test-databases.lock`, shared with Minitest, and refuses a
concurrent test process. Do not run database preparation or resets concurrently. It creates and
drops no PostgreSQL databases. Existing databases from the retired isolated workflow remain
untouched. The listener `127.0.0.1:3198` is reserved before DB preparation. Chromium uses
`http://auth.app.localhost:3198`; no remote application URL is configurable. Browser DNS is pinned
to loopback. Playwright request forwarding connects to the literal loopback address with the Auth
Host header, so a workstation DNS override cannot redirect the run elsewhere. `webServer` waits for
the bootstrap readiness message after Puma starts, and the test then requires a real HTTP 200.

## Running and inspecting failures

```bash
bun run test:e2e:rails
bun run test:e2e:rails e2e/rails/auth-public.spec.ts
bun run test:e2e:rails --headed
bun run test:e2e:rails --debug
node node_modules/playwright/cli.js show-trace tmp/e2e-rails/results/<case>/trace.zip
```

An optional `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium` selects an installed system browser
with its sandbox enabled. Otherwise install the Playwright-managed Chromium matching the lockfile.
Linux is the verified lifecycle platform; Windows graceful signal handling is not supported.

The test supplies the real `ri=jp` region query up front; region normalization redirects are not
needed by this scenario. Vite is built in test mode into `public/vite-e2e-test`, with separate
`tmp/cache/vite-e2e` build metadata. It does not depend on or replace Minitest's Vite output/cache.

Failures retain `trace.zip`, `test-failed-1.png` and Playwright error context under
`tmp/e2e-rails/results/`. These files are local and gitignored; another run replaces results. Copy
needed artifacts to an approved local location before rerunning. `log/e2e-rails.log` is the separate
Rails request log; startup/preflight errors appear in the command output. A normal Minitest run
keeps its own logging and default CSRF policy.

Traces capture response bodies and cookies, including ephemeral test CSRF/session material. This
suite uses only a public page and disposable local identities. Keep artifacts private, delete them
when diagnosis ends, and never upload them automatically. Adding authentication scenarios requires
an explicit artifact/redaction policy for synthetic credentials and tokens.

## Data ownership, reset and recovery

The bootstrap uses the ordinary configured test databases. `DatabaseSafety` checks effective
connection targets before Active Record initialization and verifies the catalog before HTTP service.
Before accepting browser traffic, every registered connection pool checks `current_database()`
against its configured test target. Reader roles retain their ordinary test configuration.

No fixtures or Minitest transactions are loaded. Startup explicitly prepares only the process-local
public availability switch; reference data must already be present in the prepared test databases.
The existing public scenario is read-only. Each invocation has a fresh browser context and unique
Valkey run/worker scope, but PostgreSQL data persists. Adding mutable scenarios requires an explicit
per-scenario synthetic-data lifecycle; this runner does not provide database reset.

On success, failure or graceful INT/TERM, Puma stops, database connections close and only the owned
Valkey prefixes are removed. No PostgreSQL database is deleted or rebuilt. SIGKILL or exhausted
grace can leave namespaced Valkey keys; retain the printed scope and verify no owner remains before
scoped cleanup. Never use FLUSHDB/FLUSHALL. The OS releases the process lock on exit. Retired
isolated-workflow databases and receipt files require separate inventory and cleanup approval.

## Boundaries and next scenarios

The bootstrap explicitly prepares only the Auth public availability flag through a shared,
process-local test Flipper memory adapter. The ordinary application availability gate remains in
place; no authentication or provider-availability switch is enabled.

The E2E mode is rejected outside explicit `RAILS_ENV=test`. In this mode CSRF is enabled; ordinary
Minitest keeps its existing default. Test mail/SMS/job adapters remain mandatory. Faraday and
Net::HTTP requests fail explicitly; no provider is mocked into success. These guards cover the
application HTTP transports, not arbitrary native socket code; additional transports need a denied
boundary before use. The browser fixture blocks service workers, WebSockets, remote origins and all
HTTP redirects before following them. HTTP/JavaScript errors fail the test. The shared layout's
exact passive Turnstile bootstrap script URL is aborted and annotated as a blocked dependency; the
test also verifies Turnstile is absent. This is a declared scenario limit, not a successful fake
challenge. Every other remote request fails the test. Real local responses pass unchanged to
Chromium through Playwright routing; there is no dummy product page.

The Auth landing's Sign in link deliberately targets HTTPS Base authority. This milestone does not
click it or rewrite that production contract. A future navigation test needs an explicitly local TLS
Base origin and an allowlist covering every redirect hop. Sign in/up also need a reviewed
synthetic-data setup/reset interface, admission/ceremony prerequisites, test-only provider delivery
inspection, and an artifact policy. Passkeys, full SSO, Jump/Away and Edge remain outside this
scope.

The existing CI has no Rails browser E2E job. This command is not silently appended to CI or
`config/ci.rb`: CI must first prepare the ordinary test databases/credentials and install Chromium.
The suite is serial and local by design.

The lifecycle follows Playwright's official
[webServer documentation](https://playwright.dev/docs/test-webserver) and uses
[route.fetch](https://playwright.dev/docs/api/class-route#route-fetch) with redirects disabled.
