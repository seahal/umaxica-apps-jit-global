# Node LTS and pnpm toolchain alignment

Date: 2026-08-09

## Why

The repository declared three different Node majors and three different pnpm versions, and the
development image installed `pnpm@latest`, so no two rebuilds produced the same toolchain.

| Declaration                                 | Before                       |
| ------------------------------------------- | ---------------------------- |
| `Dockerfile` node stage                     | `node:26-trixie-slim`        |
| `.github/workflows/ci.yml`                  | Node `24`                    |
| `README.md`, `docs/hld.md`, `docs/srs.md`   | Node `22.13+`, pnpm `11.0.8` |
| `package.json#packageManager`               | `pnpm@11.1.3`                |
| `Dockerfile` pnpm install                   | `pnpm@latest` (unpinned)     |
| `pnpm-workspace.yaml` catalog `@types/node` | `26.1.2`                     |

## Node version selection

`nodejs/Release/schedule.json` records v24 (`Krypton`) entering LTS on 2025-10-28 with maintenance
starting 2026-10-20, and v26 entering LTS only on 2026-10-28. On 2026-08-09 v24 is therefore the
Active LTS line and v26 is still Current. The newest v24 patch in `nodejs.org/dist/index.json` is
**24.19.0** (2026-08-03, npm 11.17.0).

The version is pinned to the exact patch (`node:24.19.0-trixie-slim`) rather than the floating
`24-trixie` tag so that this repository and `umaxica-apps-edge` cannot resolve to different Node
builds from the same declaration.

## Runtime and type-definition relationship

Runtime Node **24.19.0** is paired with `@types/node` **24.13.3**, the newest release in the 24.x
line. The previous `26.1.2` pin described APIs that a Node 24 runtime does not provide, so
`tsc --noEmit` was validating against a runtime the project does not ship. DefinitelyTyped tracks
the Node major in its own major, so the correct pairing is major-for-major; `@types/node` 26.x is
only appropriate once the runtime moves to Node 26 after 2026-10-28.

## pnpm

Selected **11.20.0**, the `latest` dist-tag on the npm registry (published 2026-08-03). `next-12`
resolves to `12.0.0-rc.1` and is excluded as a prerelease.

pnpm 11 honours `package.json#packageManager` natively (`manage-package-manager-versions`), so
recording the version with its `sha512` integrity is sufficient to pin the running pnpm — Corepack
does not need to be enabled. This was confirmed live: the running pnpm switched from 11.1.3 to
11.20.0 on the first install after the manifest change.

The `Containerfile` still installs pnpm via `npm install -g` so the binary exists before any
workspace checkout, but now at a pinned `ARG PNPM_VERSION` instead of `@latest`.

## The `pn` command

`pn` previously resolved to `/usr/local/bin/pn -> ../lib/node_modules/pnpm/bin/pnpm.mjs`, an
incidental artefact of pnpm's own npm `bin` map. Nothing in the repository declared it, so it would
disappear silently if the pnpm install method ever changed.

It is now created explicitly in the `development` target as a wrapper that forwards every argument:

```sh
#!/bin/sh
exec pnpm "$@"
```

An executable in `/usr/local/bin` was chosen over a `bashrc` alias because it also works in
non-interactive shells, IDE terminals, and hook invocations. The `production` target ships no Node
toolchain, so `pn` cannot leak into production.

The wrapper has to `rm -f /usr/local/bin/pn` before writing. `npm install -g pnpm` has already
created that path as a symlink to `lib/node_modules/pnpm/bin/pnpm.mjs`, so redirecting into it
writes _through_ the symlink and replaces pnpm's real entry point — which `/usr/local/bin/pnpm`
points at too — with the two-line wrapper. The wrapper then resolves `pnpm` through `PATH` back to
itself and execs in a loop: every pnpm invocation spins at 100% CPU and never returns. This was
observed on 2026-08-10; it stalled Vite builds and, through them, Rails requests, because
`vite_ruby` waits on the build. The failure is invisible in the build log, so keep the `rm -f`.

## Supply-chain policy

`minimumReleaseAge: 4320`, `minimumReleaseAgeIgnoreMissingTime: false`, `trustPolicy: no-downgrade`,
`strictDepBuilds: true`, `allowBuilds`, and the `minimumReleaseAgeExclude` list are unchanged.

Vite 8.2.1 was published 2026-08-06T13:47Z and failed the 3-day floor by roughly one hour at install
time (`ERR_PNPM_NO_MATURE_MATCHING_VERSION`). Vite stays at **8.2.0**; no exclusion was added, since
adding one to force a same-day upgrade through would defeat the policy. Vite 8.2.1 becomes eligible
on its own after the cutoff passes.

## TypeScript 7

Retained deliberately. `pnpm-workspace.yaml` carries a hand-maintained `minimumReleaseAgeExclude`
block naming all twenty `@typescript/typescript-<platform>@7.0.2` binaries plus `typescript@7.0.2`,
which is explicit evidence of an intentional adoption rather than drift.
