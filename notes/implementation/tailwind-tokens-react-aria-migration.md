# Tailwind Token Layer And React Aria Migration Implementation Notes

## Context

- Original plan/spec: rebuild the UI foundation on Tailwind, React Aria Components, semantic HTML
  and explicit design tokens.
- Related decisions/docs/plans:
  - `adr/frontend-architecture-toolchain.md` — Vite Rails owns browser CSS; Hotwire stays the
    default interaction model.
  - `adr/theme-preference-cookie-and-param-contract.md` — `ct` is the stable theme key.
  - `docs/reference/third-party-sign-in-button-requirements.md` — Google and Apple button rules.
  - `test/integration/vite_entrypoint_contract_test.rb` — one FQDN links one surface stylesheet.
- Implementation date: 2026-08-15.

## What the reconnaissance actually found

The brief assumed legacy CSS to remove. The repository had almost none: no CSS Modules, no
CSS-in-JS, no preprocessors, no `@apply`, no inline styles, two arbitrary values, and Tailwind v4
already installed. The work that mattered was three silent defects instead.

1. **`react-aria-components` was a facade.** The package was not installed. The specifier was
   aliased in `vite.config.ts`, `vitest.config.ts` and `tsconfig.app.json` onto a 111-line local
   shim exporting a hand-written `Button` and a `TextField` that was a bare `<div>` with no label,
   description or error association.
2. **Class-based dark mode did nothing.** Tailwind v4 needs an explicit `@custom-variant dark`;
   there was none, so every `dark:` utility compiled to `prefers-color-scheme` and an explicit
   `light` choice was overridden by a dark operating system.
3. **Tailwind classes written in ERB were never generated.** Every surface stylesheet used
   `@import "tailwindcss" source(none)` with `@source` roots under `src/` only. Nothing pointed at
   `app/views`, so `rounded-3xl` and the six `dark:` utilities in the passkeys page appeared in zero
   built stylesheets. Verified by grepping `public/vite/assets/*.css` before the change.

A fourth: the twelve `docs`/`help`/`info`/`news` root documents carried an identical forty-line
embedded stylesheet with no CSP nonce. `style-src-elem` admits only `'self'`, `https:` and a nonce,
so all twelve were refused by the browser and those pages rendered unstyled.

## Decisions Made During Implementation

- Decision: key the `dark` variant on `[data-theme]` rather than on a `.dark` class.
  - Why: the server already renders `data-theme` on `<html>` from the `ct` cookie, so the first
    paint is correct with no flash, and the attribute carries all three states. A block-form
    `@custom-variant` with `@slot` handles explicit `dark` and `system` + `prefers-color-scheme`
    separately, which is what makes explicit `light` stay light under a dark OS.
  - Alternatives considered: `.dark` class (Tailwind's documented class strategy) — rejected because
    it cannot express the three-way choice without JavaScript deciding, which is what was already
    broken.
  - Follow-up needed: see "obsolete but retained" below.

- Decision: semantic tokens as `--ui-*` custom properties re-published through `@theme inline`.
  - Why: `@theme` alone is static, so a token cannot have a light and a dark value. `inline` makes
    Tailwind resolve the reference at the point of use, which is the documented pattern for
    theme-switchable colours. Every value points at a Tailwind palette step rather than a hand-mixed
    hex, so no accidental legacy value became permanent.

- Decision: keep `src/styles/base.css` and `src/styles/social_button.css`.
  - Why: `base.css` holds `:lang(ja)` line-breaking (`line-break: strict`, `word-break`,
    `overflow-wrap`) and `text-wrap: pretty`/`balance`. These are language-conditional document
    defaults with no utility equivalent and they must sit in `@layer base` so a utility can still
    win. `social_button.css` encodes Google and Apple brand requirements — the 180x40 size, the 8px
    radius, the 17px title, the "do not restyle the Google artwork" rule — which are third-party
    constraints, not design choices.
  - Follow-up needed: none. Both files' remaining rules are justified in place.

- Decision: convert `social_button.css`'s dark handling to `@variant dark` but keep its values.
  - Why: it hand-wrote a third dark convention (`.theme-dark` plus a `prefers-color-scheme` block
    against `.theme-system`) that had to be kept in step with the other two by hand. The brand
    values are untouched; only the mechanism changed.

- Decision: replace `element.style.display` with the `hidden` attribute in the four invisible
  Turnstile hosts and the passkeys page message.
  - Why: `hidden` is the platform attribute for "not rendered and not announced", it removes the
    last style writes from `src/`, and it keeps the hosts out of the accessibility tree. Note the
    passkeys message needed the _attribute_, not the `hidden` utility: the script clears it by
    setting the property, and the class would have kept `display:none` applied.

- Decision: migrate `ConfirmDialog` from native `<dialog>` to React Aria's `Modal`.
  - Why: the component called `showModal()` where available and fell back to setting the `open`
    attribute otherwise. jsdom implements neither, so every test ran the fallback — a path with no
    focus trap, no Escape and no inertness. The tested behaviour was not the shipped behaviour. One
    implementation now runs in both, and the trap, the focus restore and the inert background are
    asserted in `spec/components/confirm_dialog.test.tsx`.
  - Alternatives considered: keeping native `<dialog>` and styling it. Rejected only because of the
    untestable fork; the standards-first argument for `<dialog>` is otherwise sound and this should
    be revisited if the fallback ever disappears.

- Decision: `CookieBanner` becomes a labelled `<section>` rather than `role="dialog"`.
  - Why: it declared a dialog while providing no `aria-modal`, no focus management, no Escape and
    nothing making the page behind unavailable. Announcing a dialog that does not behave like one is
    worse than announcing a region, because it tells assistive technology the rest of the page is
    blocked when it is not.

- Decision: add `@testing-library/react` and `@testing-library/user-event`.
  - Why: the existing harness reaches into `HTMLInputElement.prototype`'s value setter to defeat
    React's change tracker. That cannot credibly test keyboard navigation, focus movement or overlay
    behaviour, all of which the migration had to demonstrate. `AGENTS.md` prefers an established
    library over a custom implementation.

- Decision: `spec/setup.ts` stubs `Element.prototype.scrollTo`.
  - Why: jsdom implements no scrolling, and React Aria calls `scrollTo` to bring the focused
    collection item into view. It throws out of an animation frame, so it surfaced as an unhandled
    error rather than a failure. The shim is test-environment only; no application code knows it
    exists.

## Deviations From Plan

- Change: the twelve landing documents were first given a single shared `landing.css`, then split
  into twelve per-surface stylesheets.
  - Why: `test/integration/vite_entrypoint_contract_test.rb` enforces that a template links only
    `src/styles/surfaces/<family>_<surface>.css`, precisely so a utility generated for one surface's
    markup cannot reach another. The shared file violated that boundary and the suite caught it. The
    repository's contract was right and the shared file was wrong.
  - Risk: none remaining; the contract test passes with 677 assertions.
  - Follow-up: note that Vite content-deduplicates the emitted assets, so `help_app.css` and
    `docs_app.css` currently resolve to the same hashed file because they compile byte-identically.
    The manifest maps each entry correctly. `side_*` resolving to `core_*` is the same effect and
    predates this work.

- Change: `public/vite-test` had to be rebuilt by hand.
  - Why: `config/vite.json` sets `autoBuild: false` for the test environment, so adding a stylesheet
    leaves the test manifest stale and `vite_stylesheet_tag` raises for the new entry. This surfaced
    as three errors in `test/controllers/help_docs_news_surface_smoke_test.rb` with a "Vite Ruby
    can't find … in the manifest" message pointing at the new landing pages. Run
    `pnpm exec vite build --mode test` after adding or renaming any surface stylesheet.
  - Risk: none once rebuilt; the smoke test passes with 147 assertions.
  - Follow-up, and worth raising on its own: the `Rails Tests` job in `.github/workflows/ci.yml`
    installs no Node or pnpm and runs no Vite build, and `/public/vite*` is gitignored, so a fresh
    runner has no `public/vite-test` at all. `ViteRuby::Manifest#lookup!` raises
    `missing_entry_error` when an entry is absent, and it only builds on demand when `auto_build` is
    set — which `config/vite.json` turns off for test. Any template calling `vite_stylesheet_tag` or
    `vite_typescript_tag` therefore depends on that directory existing. This is **pre-existing**:
    the twenty-six layouts under `app/views/layouts/**` already call those helpers. This change
    widens the exposure from those layouts to those layouts plus the twelve landing pages, which
    previously linked nothing. The fix belongs in CI — build test-mode assets before
    `bin/rails test` — rather than in the views.

- Change: page-level styling was applied to the shared chrome and the one substantive ERB page, not
  across all ~183 files carrying markup.
  - Why: the primitives and the token layer are the part that makes the rest mechanical. Restyling
    every screen is a product redesign rather than a foundation change.
  - Risk: the application still looks mostly unstyled below the chrome. No behaviour is affected.
  - Follow-up: apply the primitives to the auth ceremony forms and the identity/settings screens.

## Pre-existing Flakes Found While Verifying

Two tests fail intermittently. Neither is caused by this change; both were confirmed against `HEAD`.

1. **`spec/entrypoints/inertia.test.ts` — fixed here.** Two tests failed together under CPU
   contention with `Error: Test timed out in 5000ms`, not an assertion failure. Each dynamically
   imports a surface entrypoint, which eagerly globs every page module of that surface and pulls in
   `SurfaceLayout`'s whole tree; on a loaded machine that exceeds Vitest's 5s default, and a timeout
   mid-import leaves the _next_ test's mocks uninitialised, which is why they failed in pairs.
   Reproduced 3/3 on this branch and 2/3 at `HEAD` under 24–30 busy cores, so it is pre-existing —
   though this change does make it more likely, because `SurfaceLayout` now imports React Aria.
   Fixed by giving those two tests a 30s budget: the work is real rather than hung, so the budget
   was raised rather than the import trimmed or the assertion loosened. Verified 4/4 clean under the
   same load that previously failed 3/3.

2. **`test/models/acme_logout_transaction_test.rb:9` — left alone.** `assert_no_match(/\d{4,}/, …)`
   against a randomly generated opaque identifier. A ~21-character base62 string contains four
   consecutive digits roughly 1% of the time; one run produced `CGdh9107UUFth7PzQeunX`. Passed 6/6
   on re-run. This is a probabilistic assertion in a model test untouched by this change, so it is
   reported rather than fixed here. The assertion's intent — "this must not look like a sequential
   number" — would be better served by asserting the generator's alphabet and entropy than by
   pattern-matching one sample.

## Intentional Custom CSS Residue

Four authored stylesheets outside `surfaces/` (445 lines) and three embedded blocks survive. Each
was checked rather than assumed:

| Where                                          | Why it is not a Tailwind utility                                                                                                                                                                                                                   |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/styles/theme.css` (206)                   | It _is_ the token layer: the `dark` custom variant, the `--ui-*` palette, `@theme inline`, the shared `body` ground, the one `:focus-visible` ring and the reduced-motion block.                                                                   |
| `src/styles/base.css` (61)                     | `:lang(ja)` kinsoku (`line-break: strict`, `word-break`, `overflow-wrap`) and `text-wrap: pretty`/`balance`. Language-conditional document defaults; no utility equivalent, and they must sit in `@layer base` so a utility can still win.         |
| `src/styles/base_family.css` (36)              | Re-points `--ui-font-sans` for the base family and applies `font-feature-settings: "palt" 1` for Japanese proportional metrics. The old `html body` specificity bump is gone.                                                                      |
| `src/styles/social_button.css` (142)           | Google and Apple brand requirements — fixed 180x40, 8px radius, 17px title, "do not restyle the Google artwork". Third-party constraints, not design choices. Its dark handling now goes through `@variant dark`.                                  |
| `app/views/pwa/offline.html.erb`               | Must render with zero network, so it cannot link a stylesheet. `adr/pwa-offline-route-exception.md` gives this endpoint its own policy (`style_src :self, :unsafe_inline`, nonce disabled), so the embedded CSS is both intentional and effective. |
| `app/views/layouts/email/application.html.erb` | Mail clients do not fetch external stylesheets and do not apply CSP.                                                                                                                                                                               |
| `app/views/shared/health/show.html.erb`        | Standalone diagnostic document served outside the Vite graph; it is the one block that already carried a CSP nonce.                                                                                                                                |

One arbitrary value remains: `min-h-[60vh]` in `app/views/sign/app/passkeys/new.html.erb`. It is a
genuine one-off with no standard-scale equivalent, not a preserved legacy pixel value.
`tracking-[0.24em]` was folded into `tracking-widest`.

## Obsolete But Retained

`theme_html_class` (`app/helpers/application_helper.rb`) still emits `theme-<name>` plus `dark`, and
`src/lib/theme.ts`, `src/theme_cookie.js` and `src/controllers/theme_controller.js` still toggle
them. **No CSS selector consumes any of these classes any more** — `social_button.css` was their
last reader. They are inert markup, not a second styling system.

They were left in place deliberately. Removing `.dark` cascades: the `applied` computation in
`applyTheme` becomes unused, and `watchSystemTheme` loses its purpose entirely, because
`data-theme="system"` plus the media query inside the custom variant means the browser now
re-evaluates the system setting without any JavaScript. That reaches roughly twenty assertions
across `spec/lib/theme.test.ts`, `spec/controllers/theme_controller.test.js`,
`test/helpers/application_helper_test.rb` and `test/controllers/base/app/groups_controller_test.rb`.

Follow-up worth promoting: drop `.dark` and the `theme-*` classes, delete `watchSystemTheme`, and
collapse the three theme implementations into `src/lib/theme.ts`.

## Other Duplication Left Alone

Not styling, and out of scope for this change: `csrfToken()` exists four times (`src/lib/csrf.ts`,
`src/features/auth/csrf.ts`, `src/features/auth/signin/csrf.ts`,
`src/features/auth/signup/csrf.ts`); `SocialProviderButton` and `OtpResendButton` each exist twice;
`src/features/identity/` and `src/features/base_com/identity/` are near-identical implementations of
the same screens for different surfaces.

## Review Notes

- Tests run:
  - `pnpm check` (oxfmt, oxlint, tsc) — clean.
  - `pnpm exec vitest run` — 842 tests across 64 files, all passing.
  - `pnpm build` (production Vite build) — succeeds; 26 surface stylesheets resolve in the manifest.
  - `bin/rails test test/views` — 15 runs, 59 assertions, 0 failures.
  - `bin/rails test test/integration/vite_entrypoint_contract_test.rb` — 10 runs, 677 assertions, 0
    failures.
  - `bin/rails test` — 10128 runs, 57693 assertions, 0 failures, 0 errors, 1 skip.
  - `pnpm exec vite build --mode test` — required after adding a stylesheet; see the deviation
    above.
- Tests not run: Playwright (`pnpm test:e2e`) needs `E2E_BASE_SERVICE_URL` and
  `E2E_AUTH_SERVICE_URL` and is not run in CI either.
- Coverage: the 98% Vitest gate **was already failing before this change**. Measured at `HEAD` in a
  clean worktree: 83.08% lines. After: 83.07%. `src/components/ui` is at 100%. This change is
  coverage-neutral; the pre-existing shortfall is unrelated to it and unresolved.
- CSP and React Aria overlays. React Aria positions overlays with inline styles passed through
  React's `style` prop. Two of the three links in that argument are now checked rather than assumed:
  - `node_modules/react-dom/cjs/react-dom-client.production.js` contains **zero**
    `setAttribute("style", …)` calls and applies every style through
    `style.setProperty(name, value)`. That is a CSSOM write, which `style-src` and `style-src-attr`
    do not govern — CSP governs style attributes parsed from markup and, in browsers,
    `setAttribute("style", …)`.
  - Inertia SSR is not configured: there is no SSR entrypoint under `src/` and
    `config/initializers/inertia_rails.rb` sets none, so no `style` attribute is ever serialised
    into the initial HTML for the parser to reject.
  - **Still unverified:** the above has not been observed in a running browser, and it does not
    cover any `<style>` element React Aria may inject at runtime (the one known case,
    adobe/react-spectrum#8273, was fixed in March 2026). Load a page with an overlay under `bin/dev`
    and confirm the console reports no `Refused to apply inline style` and that nothing reaches
    `/csp-violation-report`.
- Documentation promotion needed: if the browser check finds React Aria overlays blocked by
  `style-src`, the resolution is a scoped `style-src-attr` decision recorded as an ADR — not
  `unsafe-inline` on `style-src`.
