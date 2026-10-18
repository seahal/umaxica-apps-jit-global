# ADR: pnpm installation source and version pin

**Status:** Accepted (2026-08-13)

## Context

Node.js version management, pnpm executable installation, pnpm version pinning, and the
`package.json#packageManager` field are four separate concerns. Corepack blurs them: it is a Node.js
shim that both installs a package manager and enforces `packageManager`, so a repository that uses
it has no reason to name an owner for either concern. This repository never adopted Corepack — but
it also never wrote down that it had not, which left two problems.

The first was a latent build failure. `Containerfile` linked
`/usr/local/lib/node_modules/corepack/dist/corepack.js` into `/usr/local/bin`, and nothing in the
repository invoked the result. Corepack is bundled with Node.js "from version 14.19.0 up to (but not
including) 25.0.0" (`github.com/nodejs/corepack`). The image is Node 24.19.0, so the target existed;
at Node 25 or later it would not, and `ln -sf` does not fail on a missing target. Raising
`NODE_VERSION` would have produced a dangling symlink and a clean build log.

The second was an unowned invariant. The pnpm version was declared twice — `Containerfile`'s
`ARG PNPM_VERSION` and `package.json#packageManager` — with nothing reconciling them. pnpm reads
`packageManager` itself through the `pmOnFail` setting, which replaced
`managePackageManagerVersions`, `packageManagerStrict`, and `packageManagerStrictVersion`
(pnpm.io/blog/releases/11.0). Its default is `download`: on a mismatch pnpm fetches the declared
version and continues. In this compose stack that download lands in `~/.local/share/pnpm`, which is
a named volume and is not on `PATH`, so the recovery would have created a second pnpm installation
source that `which pnpm` cannot see and that differs between a fresh container and a rebuilt one.

## Decision

### Corepack owns nothing, and is not installed

The `corepack` symlink is removed from the `development` target.
`COPY --from=node-toolchain /usr/local/lib/node_modules` still copies whatever the Node image
bundles, so the package directory may remain present and inert; nothing puts it on `PATH`. No
`corepack enable`, `corepack prepare`, or `corepack install` step exists in the image, the compose
stack, the Dev Container configuration, CI, or any documented workflow, and none may be added.

### One installation source: the npm registry, into `/usr/local`

pnpm is installed by `npm install -g "pnpm@${PNPM_VERSION}"` in the `development` and
`production-assets` targets, and nowhere else. No Dev Container feature, base image, compose
service, setup script, or version manager provides a second one, so `/usr/local/bin/pnpm` is the
only pnpm on `PATH`.

Two alternatives were rejected. pnpm's standalone installer (`get.pnpm.io/install.sh`) finishes with
`pnpm setup --force`, which writes into `PNPM_HOME` under `~/.local/share/pnpm` — a named volume
here, so an image-baked install would be masked or discarded depending on volume state — and its v11
path downloads the GitHub release asset with no signature or checksum verification, which only the
v12+ registry path performs. Fetching the release tarball directly avoids the volume problem but
requires carrying a hand-maintained checksum, since pnpm publishes no checksums file with the v11
assets. `npm install -g` verifies the tarball against the integrity the registry publishes and lands
outside every volume. It should be revisited only if the image ever stops shipping a Node runtime.

### `package.json#packageManager` is pnpm's pin, and `pmOnFail: error` enforces it

`packageManager` is retained. It is not a Corepack artefact: pnpm reads it directly, and it is what
the CI setup action reads to decide which pnpm to install. Removing it would delete the only version
declaration CI consumes.

`pnpm-workspace.yaml` sets `pmOnFail: error`. A pnpm whose version differs from the declaration
fails and names the mismatch on every surface — Dev Container, CI, the production asset build, and
host shells — instead of silently downloading a second copy. The image side is checked
independently: each `npm install -g` is followed by an assertion that `pnpm --version` equals
`PNPM_VERSION`, so the version the image ships is a build-time fact rather than an assumption.

Changing the pinned version means changing `package.json#packageManager` and `ARG PNPM_VERSION`
together, running `pnpm install --lockfile-only` so `pnpm-lock.yaml` records the new version under
`packageManagerDependencies`, and rebuilding the container. Skipping the lockfile step makes
`pnpm install --frozen-lockfile` fail with `ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE`.

`devEngines.packageManager` — pnpm's newer field, which supports ranges — is not adopted here. It
would allow a range rather than an exact version, but reading it requires a newer CI setup action
than this repository currently uses, so it is deferred to that upgrade. The lockfile verification it
used to be wanted for is no longer exclusive to it: since pnpm 12, a plain `packageManager` pin is
recorded in `pnpm-lock.yaml` under `packageManagerDependencies` as well.

## Consequences

- A developer running pnpm on the host at a version other than the declared one now gets an error
  instead of an automatic switch. This is the intended trade under
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.
- Raising `ARG PNPM_VERSION` without updating `package.json#packageManager`, or the reverse, makes
  the container fail loudly until both agree and the image is rebuilt. Catching that in CI before it
  reaches a rebuild is worthwhile follow-up work.
- Raising `NODE_VERSION` past 24 no longer carries a hidden dependency on Corepack being bundled.
