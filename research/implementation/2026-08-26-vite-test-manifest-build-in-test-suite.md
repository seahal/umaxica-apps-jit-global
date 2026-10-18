# Vite Test Manifest Build In The Rails Test Suite Implementation Notes

## Context

- Original plan/spec: none; started from a reported `bin/rails test` failure that reproduced only on
  a fresh checkout.
- Related decisions/docs/plans:
  - `research/implementation/tailwind-tokens-react-aria-migration.md` — recorded this exact exposure
    as pre-existing and concluded "the fix belongs in CI — build test-mode assets before
    `bin/rails test` — rather than in the views".
  - `research/implementation/2026-08-07-pwa-offline-rails-standard.md` — hit the same failure when
    adding the `palm` entrypoint and resolved it by rebuilding the manifest by hand.
- Implementation date: 2026-08-26.

## Problem

`bin/rails test` failed with
`ActionView::Template::Error: Vite Ruby can't find styles/surfaces/base_app.css in the manifests`
from `app/views/layouts/base/app/inertia.html.erb:21` in
`test/integration/inertia_page_contract_test.rb`.

The cause is not Vite Ruby. `config/vite.json` sets `"autoBuild": false` for the test environment,
`.gitignore` excludes `/public/vite*`, and no script, rake task, lefthook job, compose service, or
CI step built test-mode assets. Every layout under `app/views/layouts` calls `vite_stylesheet_tag`
and `vite_typescript_tag`, and `ViteRuby::Manifest#lookup!` raises when an entry is absent, so the
suite depended on a gitignored build artifact that only existed where someone had previously run
`pnpm exec vite build --mode test` by hand. That is why the failure looked environment-specific: an
environment that had run the build once kept passing until the next `src/` change made the manifest
stale.

## Decisions Made During Implementation

- Decision: build the test-mode assets from `test/test_helper.rb`, immediately after
  `config/environment` loads, via `ViteRuby.commands.build`.
  - Why: it makes the dependency explicit and satisfied everywhere instead of relying on a leftover
    artifact. `ViteRuby::Builder#build` compares a digest of the watched files against
    `tmp/cache/vite/last-build-test.json` and skips the Vite call when nothing changed, so a repeat
    run pays only for the digest. Placement is load-bearing: it runs in the parent process before
    `ActiveSupport::TestCase.parallelize` forks, so one build serves the whole run.
  - Alternatives considered:
    - `"autoBuild": true` for test in `config/vite.json` (the vite_ruby install template's own
      default). Rejected: `ViteRuby::Manifest` guards on-demand builds with a plain `Mutex`, which
      is per-process. Under the suite's process-based parallelism the first render in each of N
      forked workers could trigger N concurrent `vite build` runs writing the same
      `public/vite-test`.
    - Stubbing `ViteRuby` in the test suite. Rejected: it violates
      `.agents/harnesses/rules/generic/no-test-only-code.mdc` and would hide a genuinely missing or
      renamed entrypoint, which is exactly what these layout renders are meant to catch.
    - Committing `public/vite-test`. Rejected: a build artifact in version control.
  - Follow-up needed: the CI change below.

- Decision: fail with `abort` and a message naming the standalone command rather than letting the
  build failure surface later as a missing-entrypoint error.
  - Why: `.agents/harnesses/rules/generic/no-silent-fallback.mdc`. A failed asset build must not
    degrade into per-test render errors that name an entrypoint instead of the real cause.
  - Alternatives considered: warning and continuing. Rejected as a silent fallback.

## Deviations From Plan

- Change: the CI half of the fix is **not applied**.
  - Why: `.github/` is mounted read-only in the environment this work was done in, so
    `.github/workflows/ci.yml` could not be written.
  - Risk: the `test` ("Rails Tests") and `coverage` ("Rails Coverage") jobs install no Node, pnpm,
    or `node_modules`, so the new build aborts there with the message above. Both jobs need the
    JavaScript toolchain before `bin/rails test`. They were already broken for every
    layout-rendering test before this change; the change converts a scattered, misleading failure
    into one explicit one, but it does not make those jobs green on its own.
  - Follow-up: add to both jobs, before `Setup test databases`:

    ```yaml
    - name: Setup pnpm
      uses: pnpm/action-setup@v4
    - name: Setup Node.js
      uses: actions/setup-node@v6
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: pnpm
        cache-dependency-path: pnpm-lock.yaml
    - name: Install JavaScript dependencies
      run: pnpm install --frozen-lockfile --prod=false
    ```

- Change: no new test was added.
  - Why: the behavior guarded here is the suite's own precondition. Every layout-rendering test in
    `test/integration` already fails when the manifest is absent, which is how the defect was found;
    a test asserting "the manifest exists" would restate that and pass for the same reason.

## Stale Guidance Found

`research/implementation/tailwind-tokens-react-aria-migration.md` and
`research/implementation/2026-08-07-pwa-offline-rails-standard.md` both instruct the reader to run
`pnpm exec vite build --mode test` by hand after adding or renaming an entrypoint or surface
stylesheet. That manual step is no longer required for `bin/rails test`; the suite now builds on its
own. Those notes are historical records of their own tasks and were left unedited.

## Verification

Run in this session, from a deliberately cleaned state (`rm -rf public/vite-test tmp/cache/vite`):

- `bin/rails test test/integration/inertia_page_contract_test.rb` — 6 runs, 24 assertions, 0
  failures, 0 errors. Failed with three `Vite Ruby can't find styles/surfaces/base_app.css` errors
  before the change.
- `bin/rails test test/integration/vite_asset_nonce_test.rb test/integration/vite_entrypoint_contract_test.rb test/integration/inertia_page_contract_test.rb test/integration/layouts_stylesheet_test.rb test/integration/preference_inertia_page_contract_test.rb test/unit/views/template_compilation_test.rb`
  — 58 runs, 2948 assertions, 0 failures, 0 errors, across 12 parallel processes, confirming a
  single pre-fork build serves every worker.
- Failure path, forced with `VITE_RUBY_VITE_BIN_PATH=/bin/false` and a cleared build cache — the
  suite aborts with the new message and exit status 1 instead of rendering.
- `bin/rails test` (whole suite) — 10293 runs, 58469 assertions, 0 failures, 0 errors, 1 skip, in
  657s across 12 parallel processes. The suite exceeds a 10-minute command timeout, which is worth
  knowing before assuming a hang.
- `bundle exec rubocop --force-exclusion test/test_helper.rb` — no offenses.

Not run: the CI workflow jobs, which cannot be exercised here and are still missing the toolchain
step described above.

## Unrelated Observation

`pnpm exec` rewrites `pnpm-lock.yaml` in this worktree: it drops the `vite` and `vitest` catalog
entries and inlines the versions, reproducibly, with pnpm 11.22.0 — the version `package.json` pins.
This is not caused by the change here. Any `pnpm exec` does it, including the `oxfmt` and `oxlint`
jobs in `lefthook.yml` and `pnpm exec vite build` run by hand, so the committed lockfile and what
pnpm 11.22.0 generates have drifted apart. It is only worth naming because `test/test_helper.rb` now
reaches `pnpm exec` too, so a test run that triggers a build can leave `pnpm-lock.yaml` modified.
The lockfile modification produced while verifying this change was reverted. Diagnosing the drift
itself was out of scope.
