# Upgrade pnpm to 12.0.0

## Context

The images pin pnpm at 11.22.0 through `ARG PNPM_VERSION` in `Containerfile`, and pnpm 12.0.0 is now
published. The user asked to move the pin up at the Containerfile level.

The pin is not isolated. `pnpm-workspace.yaml` sets `pmOnFail: error`, so pnpm aborts when the
binary on PATH does not match `package.json#packageManager`. Raising only `ARG PNPM_VERSION` would
make every `pnpm` call in the container fail with a package-manager mismatch. `package.json`
(`packageManager`, `engines.pnpm`) must move in the same commit; the accompanying documentation that
states the version should follow so it does not go stale.

Registry facts checked this session (`npm view pnpm`):

- `latest` = 11.24.0; 12.0.0 is published only under the `next-12` dist-tag, and is the only 12.x
  release. The user chose 12.0.0 with that known.
- `pnpm@12.0.0` integrity:
  `sha512-ni49w5EZlYaNyUuBdcIXwn6VQI+gO0oidJd48rNPdzt3zdOznt6BcbIvzVO+ajU0Lp+smUimjvWN9kiM6Jp+Zw==`
  → hex form for `packageManager`:
  `9e2e3dc3911995868dc94b8175c217c27e95408fa03b4a22749778f2b34f773b77cdd3b39ede8171b22fcd53be6a35342e9fac9948a68ef58df6488ce89a7e67`
- `pnpm@12.0.0` declares `engines.node: >=18.*`, so the pinned Node 24.19.0 stays valid.

## Changes

### 1. `Containerfile`

- Line 22: `ARG PNPM_VERSION=11.22.0` → `12.0.0`. This is the only version literal; both the assets
  builder (line 94) and the development target (line 273) redeclare the bare `ARG` and inherit it.
- Line 347 comment says "pnpm 11 reads it through `pmOnFail`". Update the version word to 12.

The two `npm install -g "pnpm@${PNPM_VERSION}" && test "$(pnpm --version)" = "${PNPM_VERSION}"`
assertions (lines 107-108, 351-352) need no edit — they already fail the build on a mismatch.

### 2. `package.json`

- `engines.pnpm`: `">=11.22.0"` → `">=12.0.0"`
- `packageManager`:
  `"pnpm@12.0.0+sha512.9e2e3dc3911995868dc94b8175c217c27e95408fa03b4a22749778f2b34f773b77cdd3b39ede8171b22fcd53be6a35342e9fac9948a68ef58df6488ce89a7e67"`

### 3. `pnpm-lock.yaml`

Only if pnpm 12 changes `lockfileVersion` (currently `'9.0'`). Verify first (step 2 below); if it
bumps, regenerate with `pnpm install --lockfile-only` under pnpm 12 and commit the result — do not
hand-edit the version header, and do not let unrelated dependency resolutions drift in.

### 4. Documentation touch-ups (version literals only)

- `README.md:49` — `pnpm@11.22.0`
- `docs/srs.md:212`, `docs/hld.md:67` — `pnpm 11.22.0`
- `adr/pnpm-installation-source-and-version-pin.md:21,70` — prose says "pnpm 11"; update to 12. The
  ADR's decision (npm registry as the single install source, dual pin reconciled by
  `pmOnFail: error`) is unchanged, so this is a wording refresh, not a new ADR.
- `pnpm-workspace.yaml:29-36` — comment block; no version literal, verify and leave as-is.

Out of scope: `.github/workflows/ci.yml` uses `pnpm/action-setup@v4` with no `version:` input, so it
reads `packageManager` from `package.json` and follows automatically.

## Verification

1. `npm view pnpm@12.0.0 version dist.integrity` — reconfirm the integrity before committing.
2. Lockfile compatibility, without touching the repo tree:
   `npx --yes pnpm@12.0.0 install --frozen-lockfile --prod=false --lockfile-only --dir "$(mktemp -d -p "$PWD")"`
   is awkward here; instead copy `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml` into a
   scratch directory and run `npx --yes pnpm@12.0.0 install --lockfile-only` there, then diff the
   resulting `lockfileVersion` against `'9.0'`.
3. Rebuild both targets and let the built-in assertions run:
   `podman build --target development -t umaxica-dev-pnpm12 .`
   `podman build --target <assets/production target> .`
4. In the rebuilt development container: `pnpm --version` (expect `12.0.0`), `pn --version` (same —
   guards the `pn` shim regression the Containerfile comment documents),
   `pnpm install --frozen-lockfile`.
5. `pnpm test`, `pnpm -s run lint`, `pnpm -s run typecheck`,
   `pnpm exec vite build --mode production`.
6. `bin/rails test test/unit/security/development_container_contract_test.rb` — that file has local
   modifications already; confirm it still passes and that nothing there asserts a pnpm version.

Report plainly if step 2 shows a lockfile bump, since that widens the diff beyond the pin.
