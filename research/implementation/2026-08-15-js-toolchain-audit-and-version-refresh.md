# JavaScript/TypeScript toolchain audit and version refresh

Date: 2026-08-15

## Scope

An audit of the JS/TS toolchain only: package manager, formatter, linter, type checker, unit test
runner, and the frontend build. Ruby, Rails, and the Rails test infrastructure were out of scope and
are unchanged.

## Audit result

The contract the audit was asked to establish was already in place from
`2026-07-10-vite-plus-removal.md`, `2026-08-09-node-lts-and-pnpm-toolchain-alignment.md`, and
`adr/pnpm-installation-source-and-version-pin.md`:

| Concern         | Owner                                                                        | Verified |
| --------------- | ---------------------------------------------------------------------------- | -------- |
| Package manager | pnpm, pinned by `package.json#packageManager`, enforced by `pmOnFail: error` | yes      |
| Format          | Oxfmt (`.oxfmtrc.json`)                                                      | yes      |
| Lint            | Oxlint (`.oxlintrc.json`)                                                    | yes      |
| Type check      | `tsc --build` over three project references                                  | yes      |
| Unit test       | Vitest, `include` restricted to `spec/**`                                    | yes      |
| Build           | `vite build --mode production` through `vite-plugin-ruby`                    | yes      |

No ESLint, Prettier, Biome, Jest, Vite+, `vp`, Corepack, `package-lock.json`, `yarn.lock`, or
`bun.lock*` exists in the repository. The only `npm` invocation is `npm install -g "pnpm@$ARG"` in
`Containerfile`, which is the installation source the ADR selected on purpose. `npx` appears only as
a symlink the Node image ships; nothing invokes it.

`e2e/` (Playwright) is outside the Vitest `include` glob, so `pnpm test` cannot reach it. Playwright
and the existing Rails test suite were left untouched, and no Hurl exists.

## Changes

Version refresh only. Every catalog entry was compared against the npm `latest` dist-tag:

| Package | Before  | After   | Published  |
| ------- | ------- | ------- | ---------- |
| pnpm    | 11.20.0 | 11.22.0 | 2026-08-15 |
| oxlint  | 1.77.0  | 1.78.0  | 2026-08-10 |
| oxfmt   | 0.62.0  | 0.63.0  | 2026-08-10 |
| vite    | 8.2.0   | 8.2.1   | 2026-08-06 |

Already newest and left alone: Node 24.19.0 (newest v24 patch; v24 is Active LTS until 2026-10-20,
v26 becomes LTS on 2026-10-28), `@types/node` 24.13.3, TypeScript 7.0.2, Vitest 4.1.10.

pnpm 11.22.0 declares `engines.node >= 22.13`, which the pinned Node 24.19.0 satisfies. The pin was
updated in the four places that declare it — `package.json#packageManager` (with the sha512
rewritten to the hex form of the registry integrity for 11.22.0), `package.json#engines.pnpm`,
`Containerfile#ARG PNPM_VERSION`, and the three documents that quote it. CI declares no pnpm version
of its own: `pnpm/action-setup@v4` reads `packageManager`, so that field remains the single source.

`devEngines.packageManager` was considered and rejected. pnpm 11 supports it, but adopting it
alongside `packageManager` would create a second declaration of the same fact, and `packageManager`
is the one both pnpm and the CI setup action already read.

## Verification

Run against the worktree before the pnpm pin bump, with pnpm 11.20.0:

- `pnpm install`, `pnpm install --frozen-lockfile` — clean
- `pnpm format:check` — 544 files, all formatted
- `pnpm lint` — no findings
- `pnpm typecheck:verify`, `pnpm typecheck` — clean
- `pnpm test` — 65 files, 754 tests, all passing, 3.8s, with no Rails server, database, Redis, or
  browser running
- `pnpm build` — succeeded into `public/vite/assets`

Re-run after the pin bump through `node_modules/.bin` (see the limitation below): `oxfmt --check`
clean, `knip` clean.

## Limitation

The pnpm bump to 11.22.0 could not be exercised locally. The workspace has no root and no writable
`/usr/local/lib/node_modules`, so `npm install -g pnpm@11.22.0` cannot run and the local binary
stays at 11.20.0. `pmOnFail: error` therefore now refuses every local pnpm command with
`This project is configured to use 11.22.0 of pnpm. Your current pnpm is v11.20.0`, which is the
enforcement behaviour the ADR specified working as designed. A container rebuild or a CI run
resolves it; the first such run is what actually proves 11.22.0 installs and passes the gates.

pnpm 11.22.0 was published on the same day it was adopted here. `pnpm-workspace.yaml` sets
`minimumReleaseAge: 4320` (three days), which quarantines newly published _dependencies_; it does
not apply to the pnpm binary itself, so nothing blocked this. Whether the same quarantine should
govern the package manager pin is an open question and is not decided here.
