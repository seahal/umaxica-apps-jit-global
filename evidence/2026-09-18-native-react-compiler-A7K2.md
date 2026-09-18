# Native React Compiler trial (2026-09-18)

Subject: `@vitejs/plugin-react` 6.1.1 native compiler via `oxc-transform-react` 0.150.0 on Vite 8.3.0 / React 19.3.0.

## Baseline (compiler off)

- `bun run ci` — exit 0 (format, oxlint, tsc, knip, OpenAPI, Vitest coverage, production build).
- Production build: `✓ built in 1.07s`.
- Example chunks: `auth_app` 27.91 kB, `base_app` 29.38 kB, `RadioGroup` 411.47 kB gzip 127.99 kB.

## Trial

- `bun add -d oxc-transform-react` → `oxc-transform-react@0.150.0` (peer of plugin-react is `^0.145.0`; no `--force`).
- `vite.config.ts`: `react({ compiler: { logDiagnostics: true } })`.
- Babel packages not installed.

## Compiler actually applied

- Direct `oxc-transform-react` on `src/components/ui/Button.tsx` emitted `import { c as _c } from "react/compiler-runtime"` and memo cache slots (`_c(12)`).
- Production `ConfirmDialog-D3tsm5AH.js` contains `(0,s.c)(10)` / `(0,s.c)(16)` and `Symbol.for("react.memo_cache_sentinel")`.
- `RadioGroup-OP2LRbKn.js.map` sources include `react/compiler-runtime.js` and `react-compiler-runtime.production.js`.

## Diagnostics

Production `bun run build` with `logDiagnostics: true`: no fatal errors, no Vite warnings from the compiler plugin, 2333 modules transformed, `✓ built in 1.07s`.

## After enable

- `bun run check` — exit 0.
- `bun run test:coverage` — 85 files, 1057 tests passed, duration 13.06s.
- `bun run build` — success; build wall time unchanged at 1.07s.
- Chunk growth is explained by compiler memoization (e.g. `auth_app` 27.91 → 47.09 kB, `RadioGroup` 411.47 → 412.94 kB). Sourcemaps still emitted (`hidden`).

## Not run

- Playwright E2E: `e2e/` has no spec files in this tree.
- `vite dev` on port 3036: port already in use by an existing process; a second Vite (Ruby plugin binds 3036) could not be started. Fast Refresh/HMR under the compiler was not exercised in the browser.

## Decision

GO: native path only, transform proven on UMAXICA components, no diagnostics, check/test/build green, no app rewrites or `"use no memo"`.
