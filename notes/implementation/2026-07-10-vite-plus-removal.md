# Vite Plus Removal Implementation Notes

## Context

- Original request: remove Vite Plus and direct `vp` usage from the Rails frontend toolchain while
  retaining pnpm, Vite, Vitest, Oxlint, Oxfmt, TypeScript, Playwright, and Vite Rails.
- Related decision: `adr/frontend-architecture-toolchain.md`.
- Implementation date: 2026-07-10.

## Decisions Made During Implementation

- Vite and Vitest now use separate configuration files. The Vite configuration retains the Ruby,
  Tailwind CSS, Inertia, and React plugins and the existing source aliases. Vitest owns test
  discovery, jsdom, aliases, coverage output, and the existing 80 percent aggregate thresholds.
- Oxfmt checks are limited to frontend sources, specs, and frontend configuration files. A
  repository-wide Oxfmt run cannot parse Rails ERB-backed YAML and existing duplicate-key locale
  YAML, so those files remain outside the frontend formatting gate.
- The `ci` package script is invoked as `pnpm run ci`. Bare `pnpm ci` is pnpm's built-in frozen
  install command and does not run the package script.
- Lefthook is an explicit pnpm dependency and an explicit exception to the repository's minimum
  package age policy, matching the existing exceptions for frontend quality tools.
- The lockfile retains `vite-plus` text only in upstream optional peer declarations from Oxfmt and
  Oxlint. No Vite Plus package or resolution remains.

## Deviations From Plan

- The tracked `vite.config.js` contained the effective Vite, Vitest, format, lint, and staged-task
  configuration. Its Vite settings were moved to `vite.config.ts`; the remaining settings were split
  into `vitest.config.ts`, `.oxfmtrc.json`, `.oxlintrc.json`, package scripts, and Lefthook.
- The redundant `src/entrypoints/inertia.ts` forwarding file was removed because TypeScript treats
  same-basename `.ts` and `.tsx` files as a conflicting composite-project input. Vite continues to
  build the actual `inertia.tsx` entrypoint.

## Review Notes

- Baseline:
  - `pnpm install --frozen-lockfile`: passed.
  - `vp check`: failed on nine pre-existing formatting issues.
  - `vp test --coverage`: failed with no tests found because the Vite root was `src`.
  - Rails coverage: 8,990 runs, 42,556 assertions, 6 failures, 7 errors, 90.71 percent line
    coverage.
  - RuboCop: 3,662 files, 6,645 offenses.
- Final frontend verification:
  - `pnpm install --frozen-lockfile`: passed.
  - `pnpm check`: passed.
  - `pnpm test:coverage`: 19 files and 286 tests passed; 93.13 percent line coverage.
  - `pnpm exec lefthook validate`: passed.
  - `bin/vite build`: passed with Vite 8.0.16.
- Final repository-wide verification:
  - Rails coverage: 9,005 runs, 42,622 assertions, 6 failures, 7 errors, 90.77 percent line
    coverage. The failure clusters match the baseline; concurrently added tests account for the
    run-count change.
  - RuboCop: 3,664 files and 82 offenses. Concurrent changes to RuboCop configuration changed the
    reported offense count; reported offenses remain outside this frontend migration.
