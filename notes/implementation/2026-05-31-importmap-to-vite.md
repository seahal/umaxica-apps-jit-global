# Importmap to Vite Implementation Notes

## Context

- Original request: migrate JavaScript entrypoint management from importmap to Vite Rails.
- Related docs: `adr/frontend-architecture-toolchain.md`, `docs/srs.md`, `docs/dds.md`.
- Implementation date: 2026-05-31.

## Decisions Made During Implementation

- Decision: remove app-owned importmap files and audit hooks while keeping Propshaft and
  `tailwindcss-rails`.
  - Why: layouts already load JavaScript through `vite_javascript_tag "application"`, while CSS and
    static assets still use Rails asset helpers.
  - Follow-up needed: complete gem removal is blocked while `mission_control-jobs` depends on
    `importmap-rails`.
- Decision: make `@hotwired/stimulus` and `@hotwired/turbo-rails` runtime npm dependencies.
  - Why: Vite now resolves those browser imports instead of importmap pins.
- Decision: keep the Rails public file server enabled in development.
  - Why: Vite Rails can emit auto-built files under `public/vite-dev`; if the Vite dev server is not
    serving a request directly, Rails still needs to return those files instead of routing the
    request to the application and producing a 404.

## Deviations From Plan

- Change: `importmap-rails` remains in `Gemfile.lock`.
  - Why: it is a transitive dependency of `mission_control-jobs`.
  - Risk: low for app JavaScript; do not re-add `config/importmap.rb`, `bin/importmap`, or layout
    importmap tags for this transitive gem.
  - Follow-up: evaluate Mission Control dependency options only if full gem-level importmap removal
    becomes required.

## Review Notes

- Tests run:
  - `bin/rails test test/integration/layouts_stylesheet_test.rb`
  - `bin/rails test test/controllers/sign/app/up/emails_controller_test.rb test/integration/layouts_stylesheet_test.rb`
  - `vp test`
  - `bin/rails vite:build`
  - `bin/rails assets:precompile`
- Tests with unrelated/pre-existing failures:
  - `vp check` fails on `.github/copilot-instructions.md` formatting, which was not part of this
    change.
  - `bin/rails test` fails in social auth tests and one deadlocked visitor model test outside this
    importmap/Vite migration.
- Documentation or ADR promotion needed: ADR and stable docs were updated in this change.
