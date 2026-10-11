# Cookie Store API Migration (Browser Side)

Date: 2026-08-19

## Context

- Request: move the browser-side cookie mechanism onto the Cookie Store API (`window.cookieStore`)
  and drop the helper layer around it. Backend cookie handling (Rails, Hono) stays exactly as it is.
- No third-party cookie library was installed. The "helper" was `src/lib/cookies.ts`, which parsed
  `document.cookie` by hand, plus every spec that arranged cookies the same way.
- The browser only ever reads two JS-readable projections Rails publishes: `ct` (theme) and
  `preference_consented` (consent buffer). Nothing in the browser writes a cookie, and that has not
  changed.

## Decisions Made During Implementation

- Decision: `readCookie` and `hasRecordedCookieConsent` became asynchronous, and `document.cookie`
  parsing was deleted rather than kept as a fallback.
  - Why: the Cookie Store API is Baseline since June 2025 (Chrome/Edge 87+, Firefox 140+, Safari
    18.4+) and answers with a structured record. A `document.cookie` fallback would be a second
    implementation of the same read, and `generic/no-silent-fallback.mdc` rules out degrading
    quietly to it.
  - Alternatives considered: keeping a synchronous `document.cookie` path behind a feature test.
    Rejected as two sources of truth for one read.
- Decision: an absent `window.cookieStore` throws, naming the secure-context and browser-version
  requirement, instead of reporting every cookie as absent.
  - Why: "cannot tell" and "no cookie" are different answers, and only one of them should raise a
    consent banner. The API needs a secure context; deployed surfaces are HTTPS and development runs
    on `*.localhost`, which browsers treat as trustworthy.
  - Follow-up needed: none, but Safari before 18.4 will now log the error and rely on the server
    endpoints instead of the cookie projections.
- Decision: `ThemeControls` starts from `data-theme` on `<html>` (new `themeFromDocument` in
  `src/lib/theme.ts`) rather than from the cookie.
  - Why: a React initial state cannot await a cookie read. Rails renders `data-theme` from the same
    `ct` cookie (`ApplicationHelper#theme_cookie_value`) and `applyTheme` keeps it in step, so the
    document is the synchronous record of what the cookie last said. Same value, no flash.
  - Alternatives considered: initialising to "system" and correcting after the read - rejected
    because a dark-theme visitor would see the radio move.
- Decision: `theme_cookie.ts` passes `themeFromDocument` to `watchSystemTheme` instead of
  `readThemeCookie`, for the same reason: a media-query change must be answered with a theme, not a
  promise.
- Decision: `CookieBanner` starts hidden and is raised by whichever read says the visitor has not
  answered; a `reconciled` ref stops a slow cookie read from re-raising a banner the endpoint has
  already hidden.
  - Why: the consent buffer can no longer seed the first render synchronously. Starting hidden keeps
    a visitor who already answered from seeing the banner flash on every load, which is the flash
    the projection exists to prevent, while `/web/v0/cookie` still raises it in every other case -
    including when the cookie read fails.
- Decision: `unicorn/no-document-cookie` is now an oxlint error for application code and off for
  specs, which arrange the browser's cookie jar directly.
- Decision (second pass, same day): the `turbo:load` listener in `src/theme_cookie.ts` and both
  `router.on("success")` subscriptions (`src/inertia/surface.ts`,
  `src/components/chrome/ThemeControls.tsx`) were replaced by `watchThemeCookie`, built on the
  store's `change` event.
  - Why: a navigation is not what changes the theme. Those hooks re-read the cookie on every arrival
    to find out whether it had moved, and missed a change the server made without one. The Cookie
    Store specification fires change events for "any script-visible cookie changes", including the
    ones a response's `Set-Cookie` header makes (https://cookiestore.spec.whatwg.org/), which is
    exactly how the preference screen saves.
  - Consequences: `src/inertia/surface.ts` no longer imports `router` at all, and one mechanism now
    serves both navigation models instead of one per model.
- Decision: `src/theme_cookie.ts` applies the theme immediately when `document.readyState` is not
  "loading", instead of only on `DOMContentLoaded`.
  - Why: `turbo:load` was the second chance that covered a module evaluated after the document was
    parsed. Removing it leaves `DOMContentLoaded` as the only trigger, and an event that has already
    fired never fires again.
- Known gap: `#js-theme-cookie-value`, the theme readout `src/theme_cookie.ts` and
  `src/controllers/theme_controller.ts` publish into, is rendered by no view in this repository.
  With `turbo:load` gone it is filled on load and on cookie change but not on a Turbo visit. If a
  view starts rendering it, the Stimulus `theme` controller fills it on connect, which Turbo does
  per visit.

## Deviations From Plan

- None. The backend was not touched; no Ruby, route, or endpoint change was needed.

## Files Changed

- `src/lib/cookies.ts` (`readCookie`, `watchCookie`), `src/lib/theme.ts` (`readThemeCookie`,
  `watchThemeCookie`, `themeFromDocument`), `src/theme_cookie.ts`, `src/inertia/surface.ts`
- `src/components/chrome/ThemeControls.tsx`, `src/components/chrome/CookieBanner.tsx`
- `src/controllers/theme_controller.ts`
- `.oxlintrc.json`
- `spec/setup.ts` (jsdom has no Cookie Store API; the stand-in is backed by `document.cookie`),
  `spec/lib/cookies.test.ts` (new), `spec/lib/theme.test.ts`,
  `spec/entrypoints/theme_cookie.test.ts`, `spec/entrypoints/inertia.test.ts`,
  `spec/components/chrome/theme_controls.test.tsx`, `spec/components/chrome/cookie_banner.test.tsx`

## Verification

- `pnpm test` - 66 files, 786 tests, all passing.
- `pnpm lint`, `pnpm typecheck`, `pnpm format:check`, `pnpm deadcode` - clean.
- `pnpm test:coverage` - `src/lib` 99.1%, `src/entrypoints` 100%, `src/inertia` 93.5% with its only
  uncovered lines (31, 63) in the pre-existing `isPageModule` guard. The global 98% threshold fails
  on this worktree across ~150 untouched files. The worktree carries a large unrelated in-flight
  change set and no committed baseline, so this was not measured against a clean tree.
- Ruby tests were not run: no Ruby, view, or configuration file was changed.

## Result

- Done
