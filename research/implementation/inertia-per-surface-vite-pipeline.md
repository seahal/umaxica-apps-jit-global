# Per-Surface Inertia and the Production Vite Pipeline — Implementation Notes

## Context

- Original plan/spec: none. The work started from an audit of the Inertia Rails + Vite Ruby setup
  and the follow-up decisions recorded in that conversation.
- Related decisions/docs/plans: `adr/pwa-offline-route-exception.md` (why `side` and `palm`
  application entrypoints ship no bundle), `docs/security/observability-boundary.md` and
  `config/initializers/content_security_policy.rb` (the `strict-dynamic` script policy),
  `.agents/harnesses/rules/project/surfaces.mdc` (surface separation).
- Implementation date: 2026-08-12.

## Findings That Motivated The Change

- The production image never built Vite assets. `Containerfile` had no Node stage, CI had no asset
  job, and `production.rb` requires an `asset_host` while disabling the public file server. Nothing
  in the repository produced `public/vite`, so no layout could have rendered in production.
- `NODE_ENV=development` (set by `compose.yaml`) survives into `vite build --mode production` and
  makes `@vitejs/plugin-react` emit the React development JSX runtime. Reproduced: the same build
  produced a 382 kB React client with `jsxDEV` under the development environment and 190 kB without
  it.
- Inertia existed on one FQDN (`base/app`) while the page glob (`pages: "../pages"`) spanned every
  surface, so any future surface layout could have resolved another surface's page component.
- `vite_javascript_tag` forwards its options to `vite_preload_tag`, which builds
  `<link rel="modulepreload">` with `tag.link`. Rails' `nonce: true` shorthand is resolved inside
  `javascript_include_tag`/`stylesheet_link_tag` but not by `tag.link`, so the layouts were emitting
  `nonce="true"` literally. With `'strict-dynamic'` in `script-src` every host source is ignored, so
  those preloads were refused by the browser and reported to `/csp-violation-report`.

## Decisions Made During Implementation

- Decision: one Inertia entrypoint and one Inertia layout per user-facing FQDN
  (`src/entrypoints/inertia/<family>_<surface>.tsx`,
  `app/views/layouts/<family>/<surface>/ inertia.html.erb`), each globbing only
  `src/pages/<family>/<surface>`.
  - Why: the surface boundary has to hold in the browser bundle, not only in Rails. A scoped glob
    makes another surface's page component absent from the bundle rather than merely unused.
  - Alternatives considered: a single shared entrypoint with a runtime allowlist (rejected: the
    other surfaces' components stay in the bundle) and one entrypoint per family (rejected: `app`,
    `com`, and `org` are separate trust boundaries, not separate views of one).
  - Follow-up needed: no surface other than `base/app` renders an Inertia page yet. The page
    directories carry a `.gitkeep` until each surface has its first page.
- Decision: Rails keeps sending surface-qualified component names (`base/app/groups/index`) and the
  client strips the prefix through `surfacePageTransform`.
  - Why: the page object stays self-describing in logs and devtools, and a name from another surface
    throws instead of resolving.
  - Alternatives considered: surface-relative names (`groups/index`). Rejected because the page
    object then cannot be attributed to a surface without the FQDN.
- Decision: compile assets in a dedicated `production-assets` Node stage rather than adding Node to
  the Ruby build stage.
  - Why: `vite-plugin-ruby` reads `config/vite.json` itself, so the build needs no Ruby, and the
    runtime image inherits no Node toolchain or `node_modules`.
  - Alternatives considered: `bin/vite build` inside `production-build` (rejected: pulls Node, pnpm,
    and the whole module tree into the gem stage).
- Decision: layouts pass `nonce: content_security_policy_nonce` instead of `nonce: true`.
  - Why: it is the only form that reaches the modulepreload links, and under `'strict-dynamic'` the
    nonce is the only source expression that admits them.
  - Alternatives considered: `skip_preload_tags: true` (rejected: silently drops preloading to hide
    the violation) and adding a `script-src-elem` host allowlist (rejected: it would have to omit
    `'strict-dynamic'`, weakening the directive that currently blocks injected script elements).

## Deviations From Plan

- Change: the CI asset job was not added.
  - Why: `.github/` is mounted read-only in this environment, so the workflow could not be edited.
  - Risk: the production bundle is built and checked only by the container build until the job
    exists; a pull request can regress `NODE_ENV` without CI noticing.
  - Follow-up: add a `build-assets` job that runs `pnpm install --frozen-lockfile --prod=false` and
    `pnpm run build` with `NODE_ENV: production`, then fails if `public/vite/assets` contains
    `jsx-dev-runtime` or `jsxDEV`. The Containerfile performs both checks already.
- Change: publishing `public/vite` to the asset host is still outside the repository.
  - Why: `production.rb` sets `public_file_server.enabled = false` and requires `PUBLIC_ASSET_URL`,
    so the origin deliberately serves no static assets. Choosing the upload target is a deployment
    decision, not an application one.
  - Risk: the image now contains the compiled assets but nothing uploads them, so production still
    cannot serve JavaScript until the deploy pipeline copies `public/vite` to the asset host.
  - Follow-up: record the upload step (and its cache headers) where the deployment is defined.

## Contradictions Found

- `.containerignore` claims to be byte-for-byte equivalent to `.dockerignore`; it already was not.
  Both received the new `public/vite*` exclusions, and `.dockerignore` additionally received the
  `node_modules/` exclusion `.containerignore` already had.
- `RAILS_SERVE_STATIC_FILES=true` in the production runtime stage has no effect while
  `production.rb` sets `public_file_server.enabled = false`. Left as found.

## Removed

- `src/entrypoints/acme/{app,com,org}.ts` — referenced by no layout; each pulled Turbo, Stimulus,
  and the React islands into the build for nothing.
- `src/entrypoints/application.js` — a compatibility shim importing `application.ts`, referenced by
  no layout.
- `src/entrypoints/inertia.tsx` — replaced by the ten per-surface entrypoints.

## Review Notes

- Tests run:
  `bin/rails test test/integration/vite_entrypoint_contract_test.rb test/integration/vite_asset_nonce_test.rb test/integration/layouts_stylesheet_test.rb test/integration/inertia_page_contract_test.rb test/integration/layout_title_contract_test.rb test/integration/layout_meta_tags_test.rb test/controllers/base/app/groups_controller_test.rb`
  (all passing); `pnpm test` (296 passing); `pnpm run format`, `pnpm run lint`,
  `pnpm run typecheck`; `bundle exec rubocop` on the touched Ruby files;
  `bundle exec erb_lint --lint-all`; `vite build --mode production` under `NODE_ENV=production`,
  including a run against only the files the `production-assets` stage copies.
- Tests not run: the full `bin/rails test` suite, and any container build — no container runtime is
  available in this environment, so the `production-assets` stage is verified only by replicating
  its file set and build command locally.
- Documentation promotion needed: the surface Inertia layout/entrypoint convention belongs in
  `docs/architecture/` once a second surface has a real page.
