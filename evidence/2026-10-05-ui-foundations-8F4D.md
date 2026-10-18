# DADS foundations acceptance refinement

Performed 2026-10-05 UTC on branch `feature`, HEAD
`7de33215b055bc8f0f2721b86a04b428a049220e`. Existing and concurrent uncommitted work is present
and affects the tested worktree. Start status: `/tmp/umaxica-foundations-status-before.txt`;
1194-entry presentation/document snapshot: `/tmp/umaxica-foundations-baseline.json`. This is a
hash snapshot, not a protected-backend audit or a copy of all pre-change sources. No commit,
branch/worktree operation, reset/clean, production request, actual IdP or real message occurred.

The [canonical design](../docs/design.md), [eight decisions](../docs/reference/ui-normalization-ledger.md#foundations-acceptance-refinement),
[official source ledger](../docs/reference/digital-agency-design-system.md) and
[420-file inventory](../docs/reference/ui-view-inventory.md) record scope and adoption separately.
All eight foundations were investigated and improved using existing presentation ownership.
Reading widths/rhythm, primary support text, link states, yellow/black focus, visible choice
focus, description relationships, role-based corners and necessary overlay edges are implemented.
Decorative icons retain correct semantics; no new icon system or product function was invented.

## Baselines and observed improvement

The initial eleven foundation browser cases failed before implementation: blue 2px focus,
12px synthetic preference explanation, and 12px prose gap. Failure traces/DOM context are under
`/tmp/umaxica-foundations/before-tests/`. New outlines initially interpolated with existing button
transitions; excluding outline from the focus transition made focus immediate. The description
relationship was corrected to target the actual checkbox, retaining hidden `0` values. Modal
measurement reproduced a 1.44:1 light edge/backdrop boundary and passed after a separate overlay
boundary role. These are different checks from fixing a test that tried to click React Aria's
hidden native input: the test now clicks its real visible label, without force or production
behavior changes.

The final combined browser run passed 147/147 in 1.5m. An earlier combined run had 146 passes
and one test failure from attempting the hidden-input click; the corrected foundation file
passed 12/12 before the final combined run. No assertion, axe exclusion, test skip or coverage
threshold was relaxed to obtain success.

Rendered app-tint colors were converted by Chromium canvas to sRGB, using actual CSS tokens.
Link default / visited / active versus tinted canvas measured **5.71 / 7.40 / 6.16** in light,
**7.15 / 10.61 / 11.08** in dark. These are state-palette measurements, not a demonstration of
native visited-history appearance: browsers protect visited styling from computed-style probes.
Modal edge/surface and edge/composited canvas-backdrop measured **10.43 / 3.12** in light,
**6.75 / 7.56** in dark. Text foreground/remaining baseline palette measurements are historical
in the earlier evidence; these results do not measure every possible backdrop or edition.

Eight prose cases cover en/ja × 320/768/1024/1440px, paragraph gap at least 1.5 line heights,
reading measure within the containing Page, 200% root-font enlargement with 0.12em letter/
0.16em word spacing and 1.5 line height overrides, no page overflow, and axe A/AA tags. Viewport
and root-font resizing are not native browser zoom. Additional checks exercise immediate focus,
hover thickness, dialog Escape/focus return, checkbox description and actual FormData `0`/`0,1`,
NavList's decorative arrow/6px radius, and forced-color focus. Prior representatives still cover
local table scrolling, disabled/native validity boundaries, consent/skip/focus and reduced motion.

Screenshots and traces are synthetic-only and retained outside the repository under
`/tmp/umaxica-foundations/`. After prose/dialog screenshots were inspected; no matched full-app
before/after screenshot set is claimed for this refinement. A matched isolated Xper CSS fixture
at 320px measured its existing phase badge **12→14px** and saved `xper-badge-before/after.png`.
It is not a live Xper route test. No live credential/user information was captured.

## Executed verification

- `bun run test`: **98 files / 1126 tests passed**, latest 09:26 UTC, 13.18s.
- `bun run typecheck`: passed after presentation changes and again during final checks.
- `bun run build`: passed, **2369 modules**. `RAILS_ENV=test bin/vite build --mode=test --force`:
  passed, **2369 modules**. Existing test-build chunk warning retained; no configuration change.
- `bin/rails test test/unit/views test/integration/layouts_stylesheet_test.rb test/integration/vite_asset_nonce_test.rb test/integration/erb_layout_preference_controls_test.rb test/integration/surface_chrome_preference_controls_test.rb test/integration/layout_rendered_title_smoke_test.rb test/integration/routes/edit_org_publishing_management_route_contract_test.rb`:
  **25 tests / 1862 assertions**, zero failures/errors/skips. This ran before authenticated browser
  fixtures, avoiding concurrent fixture/DB interference.
- Test runtime: `bin/rails runner -e test scripts/ui-test-server.rb` on 127.0.0.1:3188;
  `node node_modules/vite/bin/vite.js --config e2e/presentation.vite.config.ts` on 127.0.0.1:3190.
  Existing guarded test-only setup/normal public fixture APIs were reused, with no auth bypass.
- `E2E_BASE_SERVICE_URL=http://base.app.localhost:3188/ E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3188/ node node_modules/playwright/cli.js test e2e/ui-erb-presentation.spec.ts e2e/ui-application.spec.ts e2e/ui-presentation.spec.ts e2e/ui-authenticated-presentation.spec.ts e2e/ui-ceremony-presentation.spec.ts e2e/ui-secret-reveal-presentation.spec.ts e2e/ui-foundations.spec.ts --reporter=list --output=/tmp/umaxica-foundations/final-browser-confirmed`:
  **147 passed in 1.5m**, no skips/retries/axe exclusions. Includes 10 actual anonymous checks,
  77 admitted synthetic-session GET checks, 12 isolated ERB, 15 common React, 17 ceremony,
  four one-time synthetic Secret renderings and 12 additional foundations checks. The previous
  evidence lists all eleven admitted paths/seven conditions; admission is not login issuance.
  Authenticated tracing remains off, credentials in memory, own sessions revoked by public APIs.
- Narrow `node node_modules/oxfmt/bin/oxfmt --check` passed on 54 source/browser files;
  Xper CSS was formatted separately. Narrow oxlint reported **one unrelated `eslint/curly`
  diagnostic in the existing/concurrently edited TOTP submit handler**, at
  `src/pages/auth/app/settings/totps/new.tsx:97`. That handler was not edited by this task.
  The remaining 53 files passed, and the corrected new browser file passed individually.
  This is not an all-files lint success; no lint configuration or exclusion was added.
- `git diff --check`: passed. Final file/inventory comparison: **420 actual / 420 rows**, no
  missing/stale entries. Presentation hash differences include overlapping concurrent edits;
  ownership is not inferred solely from git diff or changed-file counts.

## Scope and limits

No new production/test dependency, server prop, fetch, storage, handler, validation, navigation
URL, auth/session condition, controller/model/operation, route, CSP/nonce/cache/asset-stack
configuration is authored by this refinement. React and Propshaft use independent local rules.
Provider artwork/appearance/dimensions and original form actions/methods/hidden values remain.
Existing payload/layout/security-contract tests passed within their recorded scope; this is not
an exhaustive audit of all concurrent backend edits. Concurrent locale/security/diagram work
was preserved and is not attributed to this task.

All eight decisions are implemented and representative-verified as individually recorded.
Actual native visited-history appearance, provider-focus routes, popover-specific composition,
shared-article admission and every remaining route/state/edition are unverified. No screen
reader, Japanese system font, real iOS Safari, Firefox/WebKit or native 400% zoom was available.
Offline CSP/cache delivery, selected-Persona dashboard prerequisite, server-owned naming/menu
props and other repositories remain outside scope. Whole-product WCAG/JIS conformance is not
claimed. Dense 14px metadata, provider/avatar/cookie shapes, relay/plain/mailers and Xper's
separate placeholder layout intentionally remain distinct.
