# pnpm Store Pin and FQDN Availability Seed Implementation Notes

## Context

- Related decisions/docs/plans: `docs/reference/feature-flags.md`,
  `app/values/fqdn_availability_registry.rb`, `app/controllers/concerns/fqdn_availability_gate.rb`,
  `config/vite.rb`, `compose.yaml` (uncommitted `npm_config_store_dir` pin)
- Implementation date: 2026-08-12

Two failures were reported and turned out to be unrelated:

1. Every public FQDN answered `503 {"error":"fqdn_unavailable"}`. `fqdn_available_*` carries
   `:availability` polarity, and nothing had ever written those Flipper features, so a freshly
   prepared `platform` database closed every host.
2. Every `vite_typescript_tag` raised `ViteRuby::MissingEntrypointError`. The entrypoints and the
   manifest were both fine; the Vite build itself was failing.

## Decisions Made During Implementation

- Decision: `db/seeds.rb` enables every `FqdnAvailabilityRegistry` flag, alongside the existing
  `social_ceremony_*` block.
  - Why: both are availability flags, so "never written" reads as closed. The file already returns
    before production, which keeps a public FQDN an explicit operator decision there.
  - Alternatives considered: a `fqdn_availability:*` rake task mirroring `social_ceremony.rake`. Not
    added -- nothing in this task needed per-slot operation from the shell, and the Flipper UI
    already covers the operator path.
  - Follow-up needed: none.

- Decision: `pnpm-workspace.yaml` carries `confirmModulesPurge: false` and
  `storeDir: ~/.local/share/pnpm/store`; `.npmrc` is deleted.
  - Why: `.npmrc` held `confirmModulesPurge=false` and pnpm 11 never read it -- the setting did not
    appear in `pnpm config list` and `pnpm config get confirmModulesPurge` returned `undefined`.
    pnpm reads settings from `pnpm-workspace.yaml` now. The dead entry was actively misleading,
    because it named the exact guard whose absence broke the build.
  - Alternatives considered: keeping `.npmrc` with a kebab-case key. Rejected -- pnpm 11 reads
    neither casing from that file, so it would have been dead config again.
  - Follow-up needed: none.

- Decision: hardlinking is not achievable here and the comment says so.
  - Why: `stat -c %d` reports the same device for the store volume and the `node_modules` volume,
    which suggests linking should work, but `ln` across them fails with `Invalid cross-device link`.
    They are separate podman volume mounts. Every install copies, before and after this change.
  - Alternatives considered: moving the store onto the `umaxica-node-modules` volume, which would
    permit linking. Rejected -- the plan rules it out, because discarding that volume to recover
    from a corrupt install would then also discard the store.
  - Follow-up needed: if install cost becomes a problem, the volume layout is the thing to revisit,
    not the store path.

## Deviations From Plan

- Change: the store is pinned in `pnpm-workspace.yaml` rather than only by `npm_config_store_dir` in
  `compose.yaml`.
  - Why: the plan chose the environment variable so that no absolute container path is committed,
    but an environment variable only reaches processes started after the container is recreated. The
    running Rails server had no such variable, so vite-ruby's pnpm and the shell's pnpm still
    disagreed. `~/.local/share/pnpm/store` is pnpm's own default location, so it commits no
    container-specific path and a host-side run still resolves to that host's home.
  - Risk: low. Both mechanisms name the same absolute path inside the container, and an environment
    variable overrides the config file, so the compose pin remains correct if kept and redundant if
    dropped.
  - Follow-up: decide whether to drop the now-redundant `npm_config_store_dir` from `compose.yaml`;
    it is still an uncommitted change there.

- Change: the plan's one-time recovery (`rm -rf node_modules/.pnpm node_modules/.modules.yaml`) was
  not sufficient.
  - Why: pnpm 11 also short-circuits on `node_modules/.pnpm-workspace-state-v1.json` and
    `node_modules/.package-map.json`. With only the two files the plan names removed, `pnpm install`
    reported "Already up to date" and left `node_modules` without its `.pnpm` directory -- a broken
    tree that still looked installed. `pnpm install --force` reported the same. Removing the two
    state files as well produced a real reinstall.
  - Risk: none remaining; recorded so the next person does not repeat the half-removal.
  - Follow-up: correct the recovery snippet in the plan document if it is kept.

## Review Notes

- Tests run:
  - `bin/rails test test/integration/fqdn_availability_gate_test.rb` -- 15 runs, 2986 assertions, 0
    failures.
  - `bin/rubocop db/seeds.rb` -- no offenses.
  - `bin/repository-language-check` -- no violations in the files touched here.
  - `pnpm -s test` -- 20 files, 292 tests, all passing, after the reinstall.
  - `bin/vite build --mode=development --clear` -- succeeds.
  - `curl` against the running origin: `www.umaxica.{app,com,org}/` and
    `auth.umaxica.{app,com,org}/sign/up` all return 200.
  - `pnpm install --frozen-lockfile` -- "Already up to date", no purge; resolved and recorded store
    paths now match.
- Tests not run:
  - Full `bin/rails test`. The Ruby change is a development-only seed addition and the gate's own
    suite covers the behavior.
  - Playwright (`e2e/`) -- requires real origins.
  - Container recreation, which is what would exercise the `compose.yaml` pin.
- Documentation promotion needed: `docs/reference/feature-flags.md` was updated for the seeded
  `fqdn_available_*` flags. The store decision lives in the `pnpm-workspace.yaml` comments and this
  note; promote it if the volume layout is revisited.
