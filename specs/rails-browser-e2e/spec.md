# Rails browser E2E foundation

Status: closed

The accepted scope is a TypeScript Playwright Test command that owns a Rails test HTTP server,
Chromium, isolated PostgreSQL clones and Valkey scope, and explicit test Vite preparation. Existing
Rails, Vitest and Playwright commands retain their meaning. Authentication ceremonies, Edge services
and cross-origin SSO are excluded. No product routes or security bypasses are added.

- AC-1: The dedicated command renders the real Auth public landing in Chromium and asserts visible
  React-created DOM; JavaScript-disabled rendering cannot satisfy the assertions.
- AC-2: Startup rejects non-test execution, occupied ports, missing dependencies and unverified DB
  ownership. Only new clones of a catalog-verified isolated source fleet are used by HTTP requests.
- AC-3: CSRF is enabled for this server; mail/SMS/jobs use test adapters. Browser egress and server
  HTTP are denied outside the selected local scenario. Redirects are checked before following.
- AC-4: Success, intentional failure, rerun and SIGINT leave no running server or owned clones;
  Valkey cleanup targets only the run/worker prefixes. SIGKILL recovery is documented as manual and
  unverified, with existing receipts preserved for ownership review.
- AC-5: Failure produces local trace and screenshot artifacts. Setup, debugging, recovery and
  remaining authentication prerequisites are documented; actual verification is retained in
  evidence.

Implementation uses Playwright webServer with graceful shutdown and a Ruby bootstrap that reuses
DatabaseSafety, ParallelTestDatabaseCloner and ValkeyTestIsolation without loading test_helper. The
source fleet is an explicitly selected, pre-provisioned disposable manifest, not ordinary test DBs.
The bootstrap retargets connections before application initializers/eager loading and HTTP service.

## Acceptance disposition

Local verification is scoped to Linux, the pre-provisioned source fleet and system Chromium.
Evidence: [2026-10-17-rails-browser-e2e-Q7M2](../../evidence/2026-10-17-rails-browser-e2e-Q7M2.md).

- AC-1: passed; disabling JavaScript produced HTTP 200 but failed the real heading assertion.
- AC-2: passed; source/worker catalog checks, 65 live pool checks, occupied-port and missing-service
  refusals, and before/after source OID checks were observed.
- AC-3: passed for the public scenario; tokenless PATCH was rejected with 403; remote navigation and
  HTTP redirects failed. The exact passive Turnstile script was explicitly aborted, never mocked.
- AC-4: passed for success, failure, rerun and SIGINT; no server, clones or owned Valkey keys
  remained. Sibling namespace sentinels survived. SIGKILL recovery remains an explicit operational
  limitation.
- AC-5: passed; ZIP/PNG failure artifacts were inspected and current operational documentation was
  added at [Rails browser E2E](../../docs/operations/rails-browser-e2e.md). Interactive viewer,
  Headed and CI execution remain unverified and are not completion claims.

Distinct Auth landing links lead to HTTPS Base authority. Their navigation is excluded under the
user's safe-destination condition; no route, authentication flow or production protection changed.
Normal Minitest CSRF remains disabled by default, with the browser opt-in recorded in its owning
ADR.
