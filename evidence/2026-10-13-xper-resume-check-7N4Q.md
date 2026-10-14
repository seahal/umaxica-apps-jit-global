# Xper retirement resume environment check

## Revision and worktree

The check was performed against full commit
`45ed455caa35c0efc2139c1969f541b5b3fc2242` on branch `feature`. The worktree had uncommitted Step
5 Xper retirement changes, including the Compose alias correction described below. `one.md` and
`two.md` remained unchanged with SHA-256 `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`
and `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`, respectively.

## Observations

- `git diff -- .devcontainer/compose.yaml` shows only the removal of the three aliases
  `xper.app.localhost`, `xper.com.localhost`, and `xper.org.localhost`. The neighboring
  `core-workers-vpc.internal` and other aliases remain. This corrects the Compose content in the
  worktree.
- `findmnt -T .devcontainer/compose.yaml -o TARGET,OPTIONS` reports the `.devcontainer` mount as
  `ro`; `test -w .devcontainer/compose.yaml` exits 1. The checkout is still not writable there.
- The approved isolated PostgreSQL setup is absent: `POSTGRESQL_ISOLATED_TEST_MANIFEST` and
  `POSTGRESQL_ISOLATED_TEST_RUN_ID` are unset, no isolated manifest was found under the workspace
  `tmp/` directory or `/tmp`, and the `scripts/` directory plus `scripts/test-isolated` are absent.
- `/etc/codex/network-policy.json` is unavailable and `cloud_environment.environment_status` is
  not exposed by the active executor tools. No current permission for a direct PostgreSQL network
  connection could be established.
- No Rails test, PostgreSQL connection, Compose startup, or database preparation was attempted in
  this check. The prior test failure and earlier successful static checks are recorded in
  [`2026-10-13-xper-test-environment-blocker-8K2P.md`](2026-10-13-xper-test-environment-blocker-8K2P.md)
  and [`2026-10-13-xper-rails-retirement-Q4V7.md`](2026-10-13-xper-rails-retirement-Q4V7.md).

## Result

The requested alias removal is present in the worktree, but the mount remains read-only. More
importantly, the test environment still lacks its approved isolated manifest and verified network
path. The new retired-host request test and twelve shared regression selectors therefore remain
unverified; Step 5 is incomplete. Do not substitute the default `test_*` fleet or bypass
`Umaxica::TestEnvironment::DatabaseSafety`.
