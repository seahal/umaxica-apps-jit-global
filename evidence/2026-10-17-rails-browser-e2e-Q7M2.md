# Rails browser E2E foundation verification

Date: 2026-10-17 UTC. Branch: `feature`. Commit: `17903f7d121aa33efe29f2db9235c9aa5db4b001`. The
worktree had extensive pre-existing staged/unstaged/untracked changes, plus the uncommitted E2E
foundation described here. These results apply to that worktree, not clean HEAD.

## Environment and implementation

Ruby 4.0.7, Bun 1.4.0, Playwright 1.64.1, system Chromium 155.0.8059.39 on Linux. The configured
cloud environment-status tool and `/etc/codex/network-policy.json` were unavailable; local
process/service probes were used. No GitHub checkout, dependency update or production service was
used. The existing Ruby and JavaScript dependencies were installed already.

Existing Playwright covers presentation fixtures and specialized Secret/admission tests that require
externally supplied servers/runners. Existing Capybara/Playwright Ruby gems remain unused by this
TypeScript foundation. `test:e2e` retains its script and config; its config excludes the new Rails
suite. No changes to `bun.lock`, Vite's base config, database.yml, product controllers,
routes/views, or test_helper were needed.

All browser runs used:

```bash
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261017c1a2 \
POSTGRESQL_ISOLATED_TEST_MANIFEST="$PWD/tmp/acceptance-isolated-20261017c1a2.json" \
PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium \
bun run test:e2e:rails
```

The existing source fleet was already provisioned and migrated. Its manifest was reused, not
recreated or rebuilt. Fresh `_0` worker clones were created and removed by the existing receipt
verification/cloner. The server required test credentials, generated a new cookie secret, enabled
CSRF, and built Vite test assets through its own preparation path. Final assets/cache are separate
from Minitest (`public/vite-e2e-test`, `tmp/cache/vite-e2e`).

## Scoped files

Added:

- `playwright.rails.config.ts`
- `scripts/e2e/server.rb`, `scripts/e2e/http_guard.rb`
- `e2e/rails/settings.ts`, `e2e/rails/fixtures.ts`, `e2e/rails/auth-public.spec.ts`
- `docs/operations/rails-browser-e2e.md`
- `specs/rails-browser-e2e/spec.md`
- This evidence record.

Modified:

- `package.json`, `playwright.config.ts`, `tsconfig.e2e.json`
- `config/boot.rb`, `config/environments/test.rb`
- `test/support/parallel_test_database_cloner.rb` (public receipt-path accessor only)
- `adr/csrf-protection-disabled-in-test-environment.md`
- `docs/operations/test-environment.md`

## Successful execution and isolation

- The permanent `Auth public landing mounts its Inertia React page` test passed repeatedly. Final
  reviewed implementation: **1 passed in 17.5 s**, exit 0. It received HTTP 200 at
  `http://auth.app.localhost:3198/?ri=jp` and asserted visible React-created
  heading/navigation/link, CSRF meta, exact URL, and absence of the explicitly blocked Turnstile
  API.
- Startup reported 32 verified owned clone DBs and checked **65 live connection pools** with
  `SELECT current_database()`; every pool addressed its owned clone.
- A separate live catalog probe observed 32 clones before the browser test and 0 after shutdown. All
  32 source database OIDs remained equal to their manifest values before/after.
- For scope `rails-e2e-a1f88ed5-c589-4b33-8854-878852ab952c:browser`, the probe wrote synthetic
  rate-limit/auth-state keys in Valkey test DBs 4 and 6, and sibling-scope sentinels. After the run,
  owned keys/prefixes were empty and sibling sentinels still existed. The probe then deleted only
  its exact sibling sentinel keys. No FLUSH operation was used.
- Final independent catalog/SCAN observation: owned clone count 0; E2E browser-scope keys 0 in both
  Valkey DBs 4/6. `ss -ltnp` and process inspection showed no listener on 3198 and no
  `ruby scripts/e2e/server.rb` process after runs.

## Failure, refusal and interruption probes

Temporary Playwright diagnostic files were executed and then removed; they are not permanent suite
additions. A final diagnostic invocation gave **4 expected failures, 1 pass**, exit 1:

- An intentionally absent heading failed after a real React page rendered.
- With JavaScript disabled, HTTP still returned 200, but the real heading assertion failed. Initial
  Inertia JSON alone therefore cannot satisfy this suite.
- A tokenless PATCH to the real Auth preferences endpoint returned **403**. Rails logged
  `security.csrf.request_blocked` and handled `InvalidCrossOriginRequest`; no mutation succeeded. An
  earlier diagnostic expected 422 and failed; it was corrected to this application's real 403
  contract before the passing probe.
- A real region-normalization 302 was refused before following it.
- Navigation to an unlisted external origin was aborted and failed without outbound browser access.

Four retained trace ZIP archives passed integrity checks, and two failure PNGs passed signature
checks. The rendered-page screenshot was visually inspected. Private local copies remain under
`tmp/e2e-rails/negative-evidence/`; they contain ephemeral test CSRF/cookie material and are not
committed or uploaded. The graphical trace viewer was not exercised.

A separate diagnostic waited after successful React rendering, then received SIGINT. Playwright
returned **130**, reported one interrupted test, and the server logged completed clone/Valkey
cleanup. The normal command subsequently succeeded again.

Additional observed refusals:

- Occupying the listener with an unrelated socket produced exit 1 / `EADDRINUSE`, before any DB
  preparation. The command never adopted it.
- `RAILS_ENV=production` was rejected by the Playwright config; setting the E2E flag with production
  was also rejected by Rails boot, both exit 1.
- A generic `RAILS_MASTER_KEY` override was rejected before application initialization, exit 1.
- A nonlocal KVS hostname was rejected before application initialization, exit 1.
- An unavailable Valkey port produced exit 1. Even though Valkey cleanup also failed, the nested
  ensure completed DB cleanup; the receipt recorded `cleanup_completed: true`, and no server or
  clones remained. The bootstrap now prints a named Valkey service/configuration diagnostic.
- Public `Net::HTTP.get` and `Faraday.get` calls were rejected before connecting. An adversarial
  probe exposed that denying Net::HTTP.request was too late (get/start opens the socket first); the
  guard was moved to connect and the public-API probes then passed.

Early development runs also failed on an incorrect Puma listener API, thread-local test Flipper
availability, region normalization, and a blocked shared-shell Turnstile script. These were not
counted as passes. The implementation now shares a process-local Flipper memory adapter, prepares
only Auth public availability through its ordinary flag API, supplies `ri=jp`, and aborts/annotates
only the exact passive Turnstile bootstrap request. No challenge success is simulated.

## Regression and static checks

- Focused Rails tests: `standard_csrf_invariant_test.rb`,
  `csrf_verification_strategy_invariant_test.rb`, `parallel_test_database_cloner_test.rb`: **11
  runs, 20 assertions, 0 failures, 0 errors, 0 skips**. The first invocation failed closed because
  inherited `POSTGRESQL_TEST_PREPARE_DATABASES` named ordinary test DBs. The successful invocation
  explicitly derived that variable from the selected isolated manifest and used
  `PARALLEL_WORKERS=2`; no source rebuild was performed.
- `bun run test gait/components/ui/button.test.tsx gait/components/ui/links.test.tsx`: **2 files, 21
  tests passed**.
- TypeScript E2E project check, targeted oxfmt/oxlint, targeted RuboCop (5 Ruby files), and
  `git diff --check`: passed on the final code.
- `bun run test:e2e ui-foundations --list`: existing **12 tests** collected successfully. Unfiltered
  `test:e2e --list` still requires the existing Secret/admission environment/runners; it failed on
  their explicit missing configuration, not on the new Rails suite.

## Adversarial review and limits

The review specifically examined serialized-HTML false positives, wrong-database deletion, CSRF
disabling, failed React/Vite startup, DNS overrides, redirect egress, namespace leakage, partial
preparation and cleanup errors. Source OID/owner/comment receipts and active-session checks remain
the deletion authority; existing unknown clone names are refused. Namespace cleanup reuses the
existing prefix-scoped implementation. No product security policy was bypassed.

Not executed: full Rails/Vitest suites, the existing external-server browser scenarios, CI,
Playwright-managed Chromium, interactive Headed/debug/trace-viewer operation, fresh-machine source
fleet provisioning, and SIGKILL/machine-failure recovery. INT/TERM are the verified lifecycle;
SIGKILL can preserve clones/keys and receipts for manual ownership review. HTTP guards cover
Faraday/Net::HTTP, not arbitrary native socket transports. Only the read-only public scenario is
supported; independently mutable scenarios need a per-scenario data lifecycle.

Auth's distinct linked destinations belong to HTTPS Base authority; no cross-origin link was clicked
or rewritten. Future sign-in/up needs a local TLS/redirect allowlist, synthetic data and
provider-delivery setup, and a credential-safe artifact policy. See
[operations](../docs/operations/rails-browser-e2e.md) and
[specification](../specs/rails-browser-e2e/spec.md).
