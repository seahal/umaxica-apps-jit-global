# Xper Rails Surface Retirement Evidence

## Revision and worktree

Work was performed against full commit `45ed455caa35c0efc2139c1969f541b5b3fc2242`. The worktree
contained uncommitted Step 5 Rails, test, ADR, and documentation changes that affected these
results. `.devcontainer/compose.yaml` was unchanged and mounted read-only.

## Implementation inventory

- Removed 39 Xper controllers, three views, three layouts, one stylesheet, and the Xper route file
  and route draw.
- Removed the Xper host fields and registry slots, development and production allowed-host entries,
  frontend-stack registrations, and six Xper variables from `.env.example` and
  `.env.devcontainer.example`.
- Removed the three Xper-only tests and only the Xper rows from the twelve shared test files named in
  `one.md`. Added `test/integration/xper_retired_hosts_test.rb` for former-host behavior and a
  retained Base route-owner positive control.
- Search found no Xper registration in `src/controllers/application.ts` and no Xper-specific keys in
  `config/locales/jp/en.yml` or `config/locales/us/en.yml`.
- `.devcontainer/compose.yaml` still contains `xper.app.localhost`, `xper.com.localhost`, and
  `xper.org.localhost` under `services.core.networks.frontend.aliases` (lines 162–164). It contains
  no Xper environment variables. `findmnt -T .devcontainer/compose.yaml` reported the mount as
  `ro`; the aliases could not be removed in this session.

## Checks performed

- Development application boot passed with the six `PUBLIC_XPER_*` and `PRIVATE_XPER_*` variables
  unset and `UMAXICA_ENV_FILE` set to the updated `.env.devcontainer.example`. With
  `RUBY_DEBUG_ENABLE=0`, the runner confirmed no Xper routes, route file, controller directory, host
  slots, or explicit retired-host entries in the development host allowlist.
- Route recognition checked six former hosts across eight paths: `/`, `/health`, `/revision`,
  `/api/v0/health.json`, `/api/v0/revision.json`, `/csp-violation-report`, `/robots.txt`, and
  `/sitemap.xml`. It found zero product-surface controller matches. The retained
  `base.app.localhost` host recognized all eight paths as Base routes.
- `ConfigValues::HostFamilyValues.build(env: host_inputs, production: true)` succeeded with 28
  non-Xper host inputs; the input had no Xper keys and the resulting value type had no Xper fields.
- Ruby syntax checks passed for 18 changed Ruby files. RuboCop passed for 17 changed tracked Ruby
  files and the new integration test. `config/frontend_stacks.yml` parsed as YAML, all six changed
  ADR links resolved, and `git diff --check` passed.

## Checks not completed

`bin/rails test test/integration/xper_retired_hosts_test.rb` stopped before test loading with
`Umaxica::TestEnvironment::ConfigurationError`: `POSTGRESQL_TEST_PREPARE_DATABASES` did not cover
the 17 verified test databases. The current checkpoint had deleted `scripts/test-isolated` and
related database helpers, and the earlier isolated-test scratch manifests were absent from `tmp/`.
No test database was prepared, the safety check was not bypassed, and no Minitest test ran. The new
request behavior and shared-test regressions remain unverified.

Step 5 remains incomplete until another runner removes the three read-only Compose aliases and
recovers the approved isolated-test setup. Edge/Cloudflare configuration and persistent data were
not changed.
