# DADS components acceptance implementation

Performed on 2026-10-05 UTC on branch `feature`, HEAD
`7de33215b055bc8f0f2721b86a04b428a049220e`. The worktree already contained substantial
staged/unstaged/untracked UI, authentication, database and tooling changes, with concurrent work.
The named historical audit was not supplied. No checkout, branch, worktree, commit, push or
external write was performed. The source baseline covers 8984 paths in
`/tmp/ui-components-baseline.json`; initial status is `/tmp/ui-components-start-status.txt`.
The owned presentation/test/document path manifest is `/tmp/ui-components-owned-files.json`.
Full git diff includes other work and must not be attributed entirely to this UI refinement.

## Implemented and verified scope

All nine accepted proposals have presentation implementations, with current status in
[UI-30–38](../docs/reference/ui-normalization-ledger.md#components-acceptance-refinement).
[The design guide](../docs/design.md) is authoritative; the
[host/View inventory](../docs/reference/ui-view-inventory.md#components-acceptance-coverage-2026-10-05)
records impact without inventing routes or claiming every file is reachable.

- Existing preferences and recovery/admin choice controls now use native select/options. Existing
  option IDs, disabled stored options and parent Inertia submissions remain. Six real guest GETs
  cover app/com/org language settings in ja/en, selecting an enabled option and examining the
  existing Rails parameter name/FormData without submitting the preference.
- Input conditions precede controls; existing moniker limits are visible. Birthdate examples are
  persistent, with all original number-input constraints and data hooks. Publishing new/edit keep
  Rails helpers, method spoofing/lock_version/field values and show related support/errors.
- Ordinary tables use 16px; explicit administrative/editorial Dense tables use 14px. Keyboard-local
  scrolling has edge cues and native scrollbars. Titled cards have named subject regions and
  stronger boundaries; plain grouping panels remain divs with decorative lines.
- Rails-translated presentation-only metadata names existing navigation and disabled explanations.
  Thirteen existing Inertia layouts render the partial without new props. Base's existing chrome
  has no footer navigation and still creates none. DocumentLocale follows document language.
- Ordinary pressed buttons use opaque existing palettes; the original disabled guard remains.
  Administration result notices share one highest-urgency live group, retaining asynchronous
  announcements without competing per-notice regions. Messages and operation handlers stay intact.

## Red–green–refactor evidence

Existing behavior tests were retained while display regressions were introduced before fixes.
The initial native-select/field-order run had ten failing cases. Card semantics, birthdate
persistent explanations and notice grouping failed before their changes. Missing document locale,
Japanese footer naming, visible moniker conditions and disabled confirmation description were
reproduced in their component tests, then passed after implementation. A first disabled-description
attempt used an unavailable matcher; the corrected test failed on missing accessible description,
not on test infrastructure. Publishing support/summary-error tests failed before their changes;
a textarea assertion was corrected to account for Rails' intentional leading newline.

Browser default table text failed at 14px versus 16px, and scroll cues were absent before changes.
Settled pressed opacity failed at 0.9 versus 1 after CSS animations completed; the corrected test
waits for animations. Final image review found year-input right edge **297px** exceeding form
right edge **247px** at 320px/200% root font despite no page overflow. A failing containment test
preceded the fieldset min-width/wrapping fix, then passed. No validation or overflow hiding was
used to satisfy it. A later mechanical lint edit accidentally returned void from the opacity
assertion; it was corrected. The new guest test initially expected footer navigation that Base
intentionally does not expose; the test now asserts the preserved no-navigation contract.

## Commands and current results

```sh
bun run test
bun run typecheck
bun run build
PARALLEL_WORKERS=1 bin/rails test test/unit/views test/integration/vite_entrypoint_contract_test.rb test/integration/vite_asset_nonce_test.rb test/integration/inertia_page_contract_test.rb test/integration/preference_inertia_page_contract_test.rb test/integration/surface_chrome_preference_controls_test.rb
RAILS_ENV=test bin/vite build --mode=test --force
bin/rails runner -e test scripts/ui-test-server.rb
node node_modules/vite/bin/vite.js --config e2e/presentation.vite.config.ts
E2E_BASE_SERVICE_URL=http://base.app.localhost:3188/ E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3188/ node node_modules/playwright/cli.js test e2e/ui-application.spec.ts e2e/ui-erb-presentation.spec.ts --reporter=list --output=/tmp/ui-components-actual
E2E_BASE_SERVICE_URL=http://base.app.localhost:3188/ E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3188/ node node_modules/playwright/cli.js test e2e/ui-authenticated-presentation.spec.ts --reporter=list --output=/tmp/ui-components-authenticated-final
node node_modules/playwright/cli.js test e2e/ui-native-preferences.spec.ts e2e/ui-components-acceptance.spec.ts e2e/ui-presentation.spec.ts e2e/ui-foundations.spec.ts --reporter=list --output=/tmp/ui-components-browser-final
```

- Full Vitest: **100 files / 1135 tests passed**. Narrow final birthdate/signup/admin/avatar checks:
  **5 files / 75 passed**. Existing transport, theme-write order, validation and hidden-operation
  tests passed; no snapshots blindly updated, tests skipped or coverage thresholds changed.
- Rails current final run: **65 tests / 1893 assertions**, zero failures/errors/skips. This covers
  actual rendered Views and existing Inertia props, nonce/entrypoint and preference/chrome contracts.
  The normal repository runner was retained; its existing single-worker option prevents cloning
  interference. No test DB safety check or runner configuration was changed.
- Typecheck and production build passed (**2370 modules**). Forced test-mode build passed; its
  existing large-chunk warning was not suppressed by configuration changes.
- Final browser results: **168 passed** across the three commands above: **93 actual GET checks**
  (10 anonymous, 77 established-session representatives, six guest preference states), **12 isolated
  ActionView/Propshaft renderer checks**, **63 isolated React/foundation checks**. These categories
  are not interchangeable and do not prove all application journeys.
- Owned TS/JS source and tests passed narrowed oxlint, except AvatarForm's two pre-existing
  diagnostics on `_segment` in its grapheme-count loop. That validation implementation was not
  changed. All **29** owned TS/JS files passed oxfmt check. Scoped `git diff --check` passed.
  No repository-wide lint-success claim is made.

The first Rails attempt was blocked by an owned open DB connection. A subsequent overlapping run
observed a temporarily missing test-replica manifest and cached locale data while files changed;
its result was **65 runs, 761 assertions, five failures, 37 errors**. These failures were retained,
not called success. After stopping only owned Puma and using the existing worker setting, the
final frozen-input run passed. No test infrastructure, replica or controller repair was made here.

An authenticated browser attempt was interrupted after **13 passed, 19 failed, one interrupted,
44 not run** when stale Vite manifest references produced asset 404s. A read-only guest request
confirmed missing Select/TextField/Page/surface script paths and zero heading. Restarting the
owned server after completed test assets resolved the cached manifest; the complete **77 passed**
rerun follows above. This is recorded as an environment failure, not hidden by a skip or auth bypass.
The later component/guest run's eight test-authoring failures were fixed and the full 69-check
rerun passed. Earlier successful 57-/36-check runs are intermediate, not added to final totals.

## Browser conditions and visual review

Chromium headless via the existing Playwright runner. Component fixtures cover app/com/org,
ja/en document language, 320/768/1024/1440 CSS px, default and Dense tables, native selection,
visible birthdate help, field errors and mixed notices. Gallery checks cover light/dark/system
(OS dark), label hit areas, keyboard focus, reduced motion and dialog containment/Escape/return.
The existing foundations suite covers forced-colors focus and overlay contrast in its own scope.
Authenticated representatives cover eleven existing GETs under seven conditions: en/light at all
four widths, ja/dark at 320, en/system with OS dark at 320, ja/system with OS light at 1440.
Their existing public token APIs establish test sessions; this is not login-issuance verification.
Own sessions are revoked afterward; traces are disabled for authenticated tests. Outbound IdPs,
real SMS/mail and production data were not used.

Axe ran after displayed target states using A/AA tags, with zero violations in successful runs.
No axe exclusions were expanded. These results are scoped automated checks, not WCAG/JIS
conformance or screen-reader proof. The isolated ja fixture uses English synthetic labels to probe
language context/reflow; actual localized copy is checked by Rails routes/component tests.

200% checks enlarge the root font; this is text-size simulation, not browser zoom. 320px checks
are viewport reflow, not measured 400% browser zoom. Actual zoom, AT reading, iOS Safari/WebKit,
native mobile OS popup behavior, all locale preference transitions and every authenticated
ceremony/mutation state remain unverified. No real administrative/publishing/registration mutation
was executed just for visual testing.

Same-condition gallery baseline/after images are `/tmp/ui-components-before-{320,1440}.png`
and `/tmp/ui-components-after-{320,1440}.png`. Visually reviewed the paired 320px images, the
1440px after image and the enlarged birthdate fixture before/after containment correction.
Observed improvement: support before entry, distinguishable titled boundaries, native picker,
readable table hierarchy and no nested enlarged-field escape. Screenshots are temporary synthetic
artifacts, outside flat Markdown evidence. This does not claim all Views received visual redesign.

Actual browser color conversion measured ordinary primary/secondary/danger text at rest/hover/press
in light/dark: all tested opaque pairs met **4.5:1**. Titled-card boundary/surface measured
**4.83/6.75** in light/dark. Against actual edition canvases: app **4.03/7.20**, com **4.00/7.21**,
org **4.33/7.07**, satisfying the DADS 3:1 boundary recommendation for these measured pairs.
This does not impose 3:1 on decorative panel/row lines or classify disabled colors as enabled ones.
Other composited states remain outside these measurements.

## Critical review and preserved contracts

Owned changes stay in presentation, four existing localization bundles, tests/fixtures and docs.
No new production dependency, framework, font, CDN, analytics or stack sharing was added. The
existing dev-only axe dependency/harness was reused without package/runner/CI edits in this turn.
Models/controllers/concerns/services/routes/host constraints/server props/security headers/CSP,
session/token/Step-Up/OTP/passkey/Turnstile and authentication-result copy were not edited by this
refinement. Protected paths have unrelated concurrent differences; the whole dirty tree is not a
claim of unchanged backend code.

Diff/test review checked native input attributes, original handlers/destinations, form action/method,
PATCH spoofing, operation IDs, lock version, theme persistence and disabled guards. Native select
changes interaction appearance but retains each caller's explicit state-based JSON transport.
No feature authorization was inferred from TLD. Provider, relay, plain-error and offline contracts
remain intentional exceptions. No giant component or configuration inheritance system was added.
Initial UI-11's custom Select exception is explicitly superseded; no obsolete popover guidance is
left in the canonical guide. Implemented-but-unverified paths and out-of-scope backend naming/CSP
items remain separate in the ledger; this report does not declare the entire product complete.
