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

This command intentionally requires an **existing, disposable isolated source fleet**, prepared
through the repository's PostgreSQL isolation workflow, rather than adopting ordinary `test_*` DBs.
Select its run ID and its matching catalog identity manifest under this checkout's `tmp/`:

```bash
export POSTGRESQL_ISOLATED_TEST_RUN_ID=<source-run-id>
export POSTGRESQL_ISOLATED_TEST_MANIFEST="$PWD/tmp/acceptance-isolated-<source-run-id>.json"
bun run test:e2e:rails
```

The source run ID uses eight digits followed by up to twelve lowercase letters/digits. A manifest is
an ownership receipt, not a list of arbitrary names: it must match the configured host, port, owner,
database OIDs and the existing disposable comment. Do not hand-author one for unknown DBs. For a new
workstation without such a fleet, isolated PostgreSQL provisioning is a prerequisite; this command
does not provision a server or rebuild the source fleet. Source databases must have current migrated
schemas and public-page reference data. Do not run the source rebuild helper without the
repository's risk/recovery approval for that destructive operation.

The runner takes the same fleet lock as Minitest/rebuilds. Use a separate source fleet for
concurrent development tests. Existing worker `_0` databases cause a refusal, never forced deletion.
The listener `127.0.0.1:3198` is reserved before DB preparation. Chromium uses
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

Before application initializers/eager loading, the bootstrap reuses `DatabaseSafety` and
`ParallelTestDatabaseCloner` to create one new `_0` clone per source database, records their
OID/owner/comment receipts, verifies them, and retargets all Rails connections. Before accepting
browser traffic it opens every registered connection pool and verifies `current_database()` against
the owned clone target. Replicas address those same owned clones. Source DBs are read only as
templates; HTTP requests never use them. No fixtures or Minitest transactions are loaded. The
startup script's explicit data preparation section currently prepares only the public availability
switch. Keep future database setup there, after clone verification, using explicit application-owned
data APIs; the clone receipt cleanup owns all resulting persisted test data. Public reference data
comes from the source snapshot. Scenario-specific data must be inserted through a reviewed setup
path after clone verification, before HTTP starts; never invoke ordinary `db:reset`, fixture loading
against the source, or an HTTP reset endpoint. Currently this suite contains one read-only scenario.
Each invocation gets fresh DB clones, a fresh browser context and a unique Valkey run/worker scope.
Do not add independently mutable scenarios to a shared server without per-scenario data lifecycle.

On success, failure or graceful INT/TERM, Puma drains/stops, connections disconnect, only the owned
Valkey prefixes are removed, and the cloner verifies the receipt and absence of active connections
before dropping its new clones. Cleanup failure is reported, not treated as success. Re-running the
command is the normal safe data reset. It does not mutate/rebuild the source fleet.

SIGKILL, machine failure, or exhausted shutdown grace can leave clones/keys and their receipts. The
next run refuses existing clones. Preserve `tmp/isolated-<source-run>-worker-0-*.json` and the
printed Valkey scope for ownership review. Confirm no owning server/process/connections remain;
recovery must revalidate the original OIDs, owner, comment and prefixes using the existing cloner
cleanup method. Never delete a database based only on its name; never FLUSHDB/FLUSHALL. If identity
changed, preserve it for investigation. There is intentionally no automatic adoption of stale DBs.

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
`config/ci.rb`: CI must first supply an isolated fleet/credentials and install Chromium. The suite
is serial and local by design.

The lifecycle follows Playwright's official
[webServer documentation](https://playwright.dev/docs/test-webserver) and uses
[route.fetch](https://playwright.dev/docs/api/class-route#route-fetch) with redirects disabled.
