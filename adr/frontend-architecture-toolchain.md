# Frontend Architecture Decision: Rails + Vite Rails + Direct pnpm Tooling

## Overview

This document records the architecture for browser JavaScript and asset tooling.

## Decision

- **JavaScript runtime delivery**: Vite Rails bundles browser entrypoints from `src/entrypoints`.
- **JavaScript layer**: Turbo, Stimulus, and React/Inertia modules are imported through npm packages
  and bundled by Vite.
- **CSS and static assets**: Vite-managed browser stylesheets are the default path for app UI CSS.
  Browser assets that participate in the Vite graph live under `src`; Rails continues to serve
  non-browser assets unless a feature explicitly needs a different delivery path.
- **Development toolchain**: pnpm manages dependencies and scripts. Vite, Vitest, Oxlint, Oxfmt, and
  TypeScript run directly without a unified CLI wrapper.
- **Importmap**: The application no longer uses `javascript_importmap_tags`, `config/importmap.rb`,
  or `bin/importmap` for browser entrypoint management. `importmap-rails` may still appear in
  `Gemfile.lock` as a transitive dependency of mounted engines such as `mission_control-jobs`.

## Rationale

### 1. Single JavaScript Entry Point System

- **Benefit**: Avoids maintaining the same Turbo, Stimulus, controller, and local module graph in
  both importmap pins and Vite imports.
- **Impact**:
  - Layouts load one explicit Vite entrypoint through `vite_typescript_tag`.
  - npm dependencies are resolved by the same toolchain used for JavaScript tests.
  - Importmap audit and pin maintenance are removed from application CI.

### 2. Keep Rails Asset Pipeline Where It Fits

- **Benefit**: JavaScript migration does not force images, fonts, or non-CSS Rails assets into Vite.
- **Impact**:
  - Propshaft continues to serve static assets that do not participate in the Vite graph.
  - App UI stylesheets are imported from Vite entrypoints such as `src/entrypoints/application.ts`.
  - Mailer layouts and other non-Vite delivery paths may continue to use `stylesheet_link_tag` where
    that is still the right transport.

### 3. Rails-Oriented Frontend Complexity

- **Benefit**: Vite is used for the parts that need npm resolution, React/Inertia support, and
  JavaScript testing without replacing the Rails asset pipeline wholesale.
- **Impact**:
  - Hotwire remains the default interaction model.
  - React/Inertia modules can be introduced as explicit Vite entrypoints.
  - New abstractions are avoided unless an entrypoint or surface boundary needs them.

## Considerations & Mitigation

### 1. CI/CD and Build Strategy

- **Challenge**: Vite entrypoints need npm dependencies at build time.
- **Strategy**:
  - Keep JavaScript dependencies in `package.json` / `pnpm-lock.yaml`.
  - Run `pnpm check`, `pnpm test:coverage`, and `bin/rails vite:build` in validation paths.
  - Keep runtime Rails assets validated with `bin/rails assets:precompile`.

### 2. JavaScript Library Management

- **Challenge**: Browser runtime libraries must be explicit npm dependencies rather than importmap
  pins.
- **Strategy**:
  - Put runtime imports such as Turbo and Stimulus in `dependencies`.
  - Keep test/build-only packages in `devDependencies`.
  - Use `pnpm audit` and Ruby audits instead of `bin/importmap audit`.

### 3. Transitive Importmap Dependencies

- **Challenge**: Mounted Rails engines may still depend on `importmap-rails`.
- **Strategy**:
  - Do not reintroduce application importmap pins or layout tags for those transitive dependencies.
  - Treat complete gem removal as a separate engine dependency decision.

## Conclusion

This architecture uses Vite Rails as the single JavaScript entrypoint system while keeping Rails'
asset pipeline for CSS and static assets where it remains the simpler Rails-native fit.
