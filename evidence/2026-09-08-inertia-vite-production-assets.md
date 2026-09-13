# Inertia Vite production asset verification

## Scope

Verify that the Rails application uses Vite Ruby for its Inertia frontend, that the production
assets build successfully, and that the generated files are available for a separately managed CDN
publication step. Origin delivery by Rails and CDN publication were intentionally outside this
verification.

## Configuration inspected

- `Gemfile.lock` resolves `inertia_rails` 3.22.0, `vite_rails` 3.11.1, and `vite_ruby` 3.10.5.
- `vite.config.ts` configures `vite-plugin-ruby`, `@inertiajs/vite`, and the React plugin.
- `config/vite.json` uses `src` as the source directory and `public/vite` as the production output
  through Vite Ruby's production defaults.
- The 14 Inertia layouts each reference a surface-specific
  `entrypoints/inertia/<family>_<surface>.tsx` entrypoint with Vite Ruby view helpers.
- `Containerfile` builds the production Vite assets, checks the manifest and React runtime, and
  copies `public/vite` into the production image.
- `config/environments/production.rb` deliberately sets `config.public_file_server.enabled = false`
  and requires `PUBLIC_ASSET_URL` (or the legacy `ASSET_URL`). Rails-origin static asset delivery is
  therefore intentionally disabled.

## Verification performed

On 2026-09-08, from `/home/global/workspace`:

1. `bun run build`
   - Exit status: 0.
   - Vite 8.2.2 transformed 2,386 modules.
   - The build produced `public/vite/.vite/manifest.json`, `public/vite/.vite/manifest-assets.json`,
     and digest-named files under `public/vite/assets`.
2. A Ruby manifest check selected every key matching `entrypoints/inertia/*.tsx`, required exactly
   14 entries, and verified that the `file` named by every entry exists under `public/vite`.
   - Result: `verified inertia entrypoints and output files: 14`.
3. `VITE_RUBY_MODE=production bin/vite build`
   - Exit status: 0.
   - This exercised the Vite Ruby executable rather than only the package script.
   - Vite again transformed 2,386 modules and reported
     `Build with Vite complete: /home/global/workspace/public/vite`.

The generated files are ignored build artifacts; the only retained workspace change from this
verification is this evidence record.

## Result

The Inertia production entrypoints compile successfully through Vite Ruby, the production manifest
resolves all 14 surface-specific entrypoints, and every resolved bundle exists in `public/vite`. The
application image has a defined path for carrying those files into production.

Asset publication remains a separate deployment responsibility. No repository step uploads
`public/vite` to `PUBLIC_ASSET_URL`, and no CDN request was tested in this verification. This is
consistent with the confirmed requirement that Rails must not deliver production static assets from
the origin.

## Checks not completed

- The related Rails contract tests did not run because Rails stopped before test execution with one
  pending migration: `db/publishing_migrate/20260906120000_add_publishing_operator_provenance.rb`.
  No database migration was performed for this read-only investigation.
- CDN upload, cache headers, and HTTP delivery were not tested because the CDN publication mechanism
  will be specified separately.
- `bin/vite --version` printed the installed Vite Ruby, Vite Rails, Rails, Ruby, and Node versions,
  then exited with `Errno::ENOENT` because its diagnostic output attempted to invoke unavailable
  `npm`. This did not affect either successful production build.
