# Core browser session Dashboard and dynamic cache boundary

Performed 2026-10-04, 03:15–03:32 UTC (Etc/UTC).

- Edge repository: `/home/global/umaxica-apps-edge`, branch `main`,
  HEAD 185dd076404011ed391b2b550091be3fd7939ba0.
  Dirty paths increased from 38 at implementation start to 84 at the final
  preceding capture, including preserved earlier Core migration changes.
- Rails repository: `/home/global/workspace`, branch `feature`,
  HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5, 345 dirty paths at capture.
  This record does not claim a Rails code change or new Rails/browser integration
  test. The companion issuance-facts record covers the prior Secret results.

All results include uncommitted work; these are not CI or clean-commit results.

## Implemented boundary

All three Core units now own a Dashboard route and browser session reader.
Common SSR renders checking without fetching Rails. Browser mounting requests
only the existing same-origin `GET /api/v0/session`, with same-origin credentials,
no-store and redirect refusal. Existing response fields are consumed without
changing the Rails wire shape. Tokens and cookies are never read by JavaScript.

The component distinguishes available access, unavailable access and temporary
failure. It does not infer refresh expiry, issue a refresh POST, redirect or
log out. Explicit recheck clears the previous actor display and invalidates old
requests before starting transport; late results are ignored even when transport
ignores cancellation. Actor text is escaped. This is not full logout/subject-switch
integration or proof of authoritative reauthentication-required state.

Dynamic application responses carry no-store. Fingerprinted static assets retain
their separate immutable policy; no CDN configuration was changed.

## Commands and results

Commands used the existing local pnpm tool installation on PATH. No repository
package-manager setting, dependency, coverage threshold or lint suppression changed.
Installed React is 19.2.8; TanStack Start is 1.168.49.

- Initial reader/component new-feature tests could not import the absent modules;
  the later implementation ran 32 focused tests successfully. These import
  failures are distinct from the actual HTTP cache behavior Red below.
- Cache Red: `pnpm --dir <surface>/core run test:api`, independently on app/com/org,
  failed the new Dashboard no-store assertion because Cache-Control was absent.
  After the application response change, each suite passed 6 Hurl files and
  **31 actual HTTP requests**. Synthetic incoming Cookie/Authorization sentinels
  were absent from the SSR document. Misplaced API requests remained bodyless 404.
- `pnpm --dir <surface>/core run check`: PASS independently on app/com/org,
  **260 Vitest tests per surface**, plus formatting, lint/type-aware lint,
  generated types, typecheck and Knip. No test skip was added.
- `pnpm --dir <surface>/core run test:cov`: PASS on all three. Each reported
  100% statements (397/397), branches (162/162), functions (119/119),
  and lines (380/380), preserving the existing 100% thresholds.
- `pnpm --dir <surface>/core run build` and `run check:size`: PASS on all three.
  Gzipped sizes: app 119.27 kB, com 119.28 kB, org 119.27 kB;
  existing budget 129 kB.
- `pnpm --dir app/core exec playwright install chromium`: installed the existing
  runner's browser locally. `pnpm --dir <surface>/core run test:e2e`: PASS,
  **5 Chromium tests per surface** after the cache change. Actual local Worker
  misrouting produced the failure UI after a browser-originated API request.
  The actor-response fixture tested escaped rendering and display removal;
  it did not prove Rails authentication.
- Root invariant command, with the existing EDGE_TRACKED_FILES input:
  `pnpm exec vitest run --dir test`: **433 passed, 1 existing conditional skip**.
  The skip is `compose-local-override-invariants.test.ts`, when no Compose engine
  is available. No skip or engine-construction test was introduced.
- `pnpm run check:spelling`: PASS, 2,168 files, zero issues after wording correction.
- `git diff --check`: PASS in both repositories at final checks.

Earlier runs exposed strict TypeScript optional-header typing, effect/lint rules,
new navigation expectations and ambiguous browser status locators. Those were
corrected without suppressions or weakened behavioral expectations. A first
check invocation lacked pnpm on the child process PATH; the existing installation
resolved it. Concurrent runtime/check starts briefly hit the host process limit
(EAGAIN); sequential checks completed successfully. No unrelated process was killed.

## Unverified and gated work

NOT_RUN: complete browser-to-Rails authenticated integration, access-expiry
continuation, real logout/subject switching, multiple tabs, delayed Set-Cookie
ordering, full twenty-unit checks and production routing/cache verification.
Local runners terminated their owned servers; no deployment or external write ran.

The remaining Core health server-side Rails probe still requires its separately
proposed response-shape change. New browser refresh behavior remains gated.
This record proves the limited application/browser boundary above, not complete
Core migration, login continuation or deployment readiness.

ADR 016 and `docs/development/core-browser-session-state.md` in Edge describe the
implemented scope and remaining contracts.
