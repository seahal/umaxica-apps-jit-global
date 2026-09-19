# Corepack Removal and pnpm Pin Enforcement Implementation Notes

## Context

- Original plan/spec: audit request to remove every Corepack dependency from the development
  container and redesign how pnpm is installed, pinned, and updated, without assuming that
  `package.json#packageManager` is a Corepack-only field.
- Related decisions/docs/plans: `adr/pnpm-installation-source-and-version-pin.md` (written by this
  change), `notes/implementation/2026-08-09-node-lts-and-pnpm-toolchain-alignment.md` (pinned the
  Node and pnpm versions and already recorded that Corepack does not need to be enabled),
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.
- Implementation date: 2026-08-13

## Decisions Made During Implementation

- Decision: keep `npm install -g "pnpm@${PNPM_VERSION}"` as the single installation source rather
  than switching to pnpm's standalone binary.
  - Why: the investigation started from the assumption that `/usr/local/bin/pnpm` might be a
    Corepack shim. It is not — it is a symlink to `../lib/node_modules/pnpm/bin/pnpm.mjs`, so the
    existing install method was already Corepack-free and already the only pnpm on `PATH`. The
    Corepack dependency was one unused `ln -sf` line.
  - Alternatives considered: `get.pnpm.io/install.sh` finishes with `pnpm setup --force`, which
    writes into `PNPM_HOME` under `~/.local/share/pnpm`; that path is the `umaxica-home-share` named
    volume in `compose.yaml`, so an image-baked install there is masked or discarded depending on
    volume state. Its v11 path also downloads the GitHub release asset with no signature or checksum
    check — verification exists only on the v12+ npm registry path. Fetching `pnpm-linux-x64.tar.gz`
    directly sidesteps the volume problem but needs a hand-maintained sha256, because the v11
    release publishes no checksums file.
  - Follow-up: revisit if the image ever drops the Node runtime.

- Decision: set `pmOnFail: error` in `pnpm-workspace.yaml`.
  - Why: `ARG PNPM_VERSION` and `package.json#packageManager` declared the same version with nothing
    reconciling them. pnpm 11's default `pmOnFail: download` resolves a mismatch by fetching the
    declared version into `~/.local/share/pnpm` and continuing — a second installation source, off
    `PATH`, inside a named volume, invisible to `which pnpm`. `error` is the only value that does
    not hide the drift.
  - Alternatives considered: `warn` and the `download` default are both silent fallbacks. A CI-only
    string comparison between the two declarations would catch bad commits but not a stale
    container.
  - Follow-up: a CI guard comparing the two declarations would move the failure earlier than a
    container rebuild. Not added here — see "Deviations".

- Decision: retain `package.json#packageManager` and do not adopt `devEngines.packageManager`.
  - Why: `packageManager` is read by pnpm itself and by the CI setup action; it is not Corepack
    configuration. `devEngines.packageManager` is pnpm 11's newer field and records its resolution
    in `pnpm-lock.yaml` under `packageManagerDependencies`, which would be a stronger pin, but
    reading it requires a newer CI setup action than this repository uses.
  - Follow-up: reconsider together with the CI action upgrade below.

## Deviations From Plan

- Change: `.github/workflows/ci.yml` was left untouched.
  - Why: the audit scope was the Dev Container, and no CI change is required for Corepack removal —
    CI never used Corepack. Two findings are reported instead of applied.
  - Risk: the findings stay open. `pnpm/action-setup@v4` (lines 67 and 457) is superseded; its
    README states the successor is `pnpm/setup` and that action-setup "remains the action to use for
    installing pnpm v10 and older", while this repository is on pnpm 11. The current major tag of
    `pnpm/setup` could not be settled — its README and the marketplace listing disagree (v2 vs v1) —
    so it must be confirmed before any migration.
  - Follow-up: (1) confirm the `pnpm/setup` major tag and migrate, which can also replace
    `actions/setup-node`; (2) add a guard step comparing `ARG PNPM_VERSION` with
    `package.json#packageManager`.

## Review Notes

- Tests run:
  - `pnpm config list` — `pmOnFail: error` is read by pnpm 11.20.0 with no unknown-setting warning.
  - Drift behaviour proved in a scratch project (`packageManager: pnpm@11.19.0`, running pnpm
    11.20.0): `pmOnFail: error` exits 1 with
    `This project is configured to use 11.19.0 of pnpm. Your current pnpm is v11.20.0`; the same
    project with `pmOnFail: ignore` exits 0.
  - `pnpm install --frozen-lockfile`, `pnpm -s run ci`, `bin/repository-language-check` on the new
    ADR and this note.
- Tests not run:
  - Image rebuild. The `Containerfile` edits (Corepack symlink removal, `pnpm --version` assertions)
    are unverified until `podman build` runs for the `development` and `production-assets` targets;
    the running container still carries the old `/usr/local/bin/corepack` symlink.
  - Forward-compatibility build with `NODE_VERSION` on Node 26. Expected to surface unrelated Node
    26 issues, and Node 26 is not Active LTS until 2026-10-28.
- Documentation promotion needed: none. The decision lives in
  `adr/pnpm-installation-source-and-version-pin.md` and the developer-facing procedure in
  `README.md`.

## Stale Guidance Found

- `compose.yaml` described `umaxica-home-cache` as "pnpm / corepack / Vite / YJIT scratch";
  corrected.
- `.github/workflows/ci.yml` line 60 carries a Japanese comment, which
  `docs/reference/repository-language-policy.md` disallows. Out of scope for this change.
