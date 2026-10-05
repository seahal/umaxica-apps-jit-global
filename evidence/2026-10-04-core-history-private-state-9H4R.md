# Core private display across page departure and history restoration

Performed 2026-10-04, 05:11–05:16 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; the preceding
status capture had 398 dirty paths, including concurrent work. Edge main HEAD
185dd076404011ed391b2b550091be3fd7939ba0, 84 dirty paths. Results include
uncommitted work and are not CI results.

Each app/com/org Core independently invalidates the session-reader generation,
aborts transport and synchronously clears private display on pagehide. A persisted
pageshow performs one new existing same-origin session GET. Initial nonpersisted
pageshow adds no duplicate read; unmount removes listeners. No refresh, token or
cookie access, timer, authentication endpoint or response shape was added.

React flushSync is limited to the native pagehide callback so clearing finishes
before that callback returns. The installed React 19.2.8 export was inspected;
its official reference documents synchronous browser integration and prohibits
calling it during rendering/effect execution. Effect setup only registers the
callback. Browser history memory is distinct from the HTTP cache; existing
no-store remains intact.

## Verification

- Red: app Vitest reproduced two failures: the departing actor remained visible,
  and an ignored cancellation allowed its late response to restore actor display.
- Happy DOM 20.12.0 aliases PageTransitionEvent to Event without persisted. The
  unit fixture uses an Event subclass carrying that browser property, rather than
  changing production detection. Chromium uses the actual native event class.
- Final `pnpm --dir <surface>/core run check`: PASS independently on all three,
  including formatting, ordinary/type-aware lint, generated types, typecheck,
  Knip and **263 Vitest tests each**. An initial unawaited act lint failure was
  corrected without suppression.
- `pnpm --dir <surface>/core run test:cov`: PASS on all three, retaining 100%
  statements (408/408), branches (164/164), functions (122/122), lines (390/390).
- `pnpm --dir <surface>/core run test:api`: PASS on all three, six Hurl files and
  31 actual local HTTP requests each.
- Final `pnpm --dir <surface>/core run test:e2e`: PASS on all three,
  **7 Chromium tests each**. One fixture checks synchronous clearing within the
  actual native pagehide callback and rechecking on synthetic persisted pageshow.
  Another performs real full-document navigation away and browser history back,
  then observes the changed actor summary without redisplaying the prior actor.
- `pnpm --dir <surface>/core run build` and `run check:size`: PASS on all three.
  Gzipped sizes app 119.39 kB, com 119.4 kB, org 119.37 kB, existing budget 129 kB.
- Root `pnpm run check:spelling`: PASS, 2,168 files, zero issues after replacing
  an unknown abbreviation in comments with plain back/forward cache wording.
- `git diff --check`: PASS in Edge before this record.

Commands used the existing /tmp/umaxica-edge-pnpm-tool/bin installation on PATH.
Checks were sequential; no gate, dependency or lint configuration changed.
The Edge browser-session-state document now states the implemented lifecycle
and the limits below.

## Limits

Transport fixtures are not Rails authentication success, authoritative logout,
subject-switch or refresh tests. Real history traversal does not prove successful
back/forward cache admission; the browser may reload instead. No browser memory
or credential secrecy claim is made beyond the tested display boundary.

NOT_RUN: full Rails/browser authentication integration, multiple tabs, delayed
Set-Cookie ordering, access-expiry continuation, all twenty deployment-unit checks,
production routing/cache verification or deployment. The Secret shape proposals,
Core health response proposal and conditional refresh decisions remain unchanged.
The overall implementation goal is incomplete.

Sources: [React flushSync](https://react.dev/reference/react-dom/flushSync) and
[Chrome back/forward cache guidance](https://web.dev/articles/bfcache).
