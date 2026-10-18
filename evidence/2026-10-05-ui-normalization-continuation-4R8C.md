# UI normalization continuation: implementation and verification

Performed on 2026-10-05 UTC, branch `feature`, HEAD
`7de33215b055bc8f0f2721b86a04b428a049220e`, with pre-existing and concurrent uncommitted work.
No commit, branch operation, checkout, reset, clean, worktree, production request, actual IdP
operation or explicit migration was performed. The earlier environment blocker was resolved
outside this presentation task. Results include local uncommitted UI changes.

The [canonical specification](../docs/design.md) links the
[420-file host/view inventory](../docs/reference/ui-view-inventory.md),
[DADS reading ledger](../docs/reference/digital-agency-design-system.md), and
[deviations, execution stages and final status](../docs/reference/ui-normalization-ledger.md).
This record continues [the earlier evidence](2026-10-05-ui-normalization-9K2M.md), rather than
rewriting its historical blocked or unverified observations as successes.

## Implemented user paths

Auth signup/OTP/passkey and Secret ceremonies now share narrow purpose/action hierarchy while
retaining native constraints and cancellation. Independent com Identity forms/lists/details/results
use the same specification within their ownership. Secret creation/rename/revocation and one-time
reveal retain their forms/hidden payload/clearing contracts; controls and stored acknowledgment are
readable and usable. TOTP inventory now exposes its supplied title and add action. Actual English
rendering failures were fixed with seven safe display-only keys in each English regional bundle.
Edit dashboard destination names and existing list/form presentation were improved. Legacy ERB
wrappers are normalized/delegated or explicitly retained as relay/provider exceptions.

## Completed checks

- `bun run test`: **98 files, 1126 tests passed**, latest run 08:42 UTC, 13.22s.
- `bun run typecheck`: passed. `bun run build`: passed, **2369 modules**. A final native-output
  lint correction on the issuance notice was followed by successful typecheck/build; no handler
  changed. `RAILS_ENV=test bin/vite build --mode=test --force` also passed before the final browser
  suite and server restart. Its existing chunk-size warning remains; no config weakened it.
- `bin/rails test test/unit/views test/integration/layouts_stylesheet_test.rb test/integration/vite_asset_nonce_test.rb test/integration/erb_layout_preference_controls_test.rb test/integration/surface_chrome_preference_controls_test.rb`:
  **17 tests, 1479 assertions**, no failures/errors/skips.
- `bin/rails test test/integration/layout_rendered_title_smoke_test.rb test/integration/routes/edit_org_publishing_management_route_contract_test.rb`:
  **8 tests, 383 assertions**, no failures/errors/skips. Combined current Rails result:
  **25 tests, 1862 assertions**. The new one-time-reveal renderer test contributes one test/16
  assertions checking escaping, acknowledgment, methods and hidden values.
- Rails Erubi sources compiled in a rendering-method wrapper: **122 templates**. This uses the
  actual Rails handler, not plain Ruby ERB's incompatible block-helper compilation.
- `node node_modules/oxlint/bin/oxlint` on 50 continuation-owned frontend/test files: passed.
  `node node_modules/oxfmt/bin/oxfmt --check` on the same set: passed. `git diff --check`: passed.
  A remaining native-status lint diagnostic was corrected using semantic output with the same
  implicit status role and display; it was not excluded or silenced.
- Final file-to-inventory comparison: **420 actual files, 420 rows**, no missing or stale entry.
- Final browser command:
  `E2E_BASE_SERVICE_URL=http://base.app.localhost:3188/ E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3188/ node node_modules/playwright/cli.js test e2e/ui-erb-presentation.spec.ts e2e/ui-application.spec.ts e2e/ui-presentation.spec.ts e2e/ui-authenticated-presentation.spec.ts e2e/ui-ceremony-presentation.spec.ts e2e/ui-secret-reveal-presentation.spec.ts --reporter=list --output=/tmp/umaxica-ui-normalization-continuation/final-browser`:
  **135 passed in 1.4m**, no retries/skips or axe exclusions.

| Browser scope | Passed | What it establishes |
| --- | --- | --- |
| Actual anonymous application | 10 | Base/Auth app roots ja/en at 320/1440px; skip/main/title/axe; existing entry POST attributes and offline native recovery |
| Actual authenticated test-fixture GETs | 77 | Eleven admitted identity/inventory/logout/settings/Edit paths at seven viewport/language/theme/OS conditions |
| Independent ERB shell fixture | 12 | Four widths × three themes; actual Propshaft CSS roles, targets, axe |
| React common gallery | 15 | Four widths/themes, label activation, local scrolling, dialog Tab/Escape/focus return, reduced motion and long-text 200% root-font reflow |
| Ceremony composition/native validity | 17 | Four existing method/checkpoint/OTP/Secret compositions × four widths; empty, 31/32/33, accepted alphabet, zero and NUL input validity partitions |
| One-time Secret ActionView fixture | 4 | Four widths, synthetic escaped value, real label target/click, continue/cancel controls and hidden payload, axe |

Authenticated GETs: Base app `/identity`, `/identity/emails`, `/secrets`, `/sign/out/edit`;
Auth app `/settings/passkeys`, `/settings/totps`; Base com `/identity/emails`, `/identity/secrets`;
Edit org `/dashboard`, `/publishing/docs/app/entries`, `/publishing/docs/app/entries/new`.
English/light covers 320/768/1024/1440px; Japanese/dark covers 320px; English/system with OS dark
covers 320px; Japanese/system with OS light covers 1440px. Normal test-fixture session and
VisitorVerification APIs satisfy existing admission; callbacks are not skipped. Cookies remain
in browser memory, traces are off for the authenticated file, and its own sessions are revoked
through the public API. Synthetic test records do not prove the login issuance journey.

## Scope and evidence review

Initial status/hashes and matched before/after artifacts remain under
`/tmp/umaxica-ui-normalization/`. Continuation snapshot (1179 source entries), changed-file list
and synthetic screenshots remain under `/tmp/umaxica-ui-normalization-continuation/`.
Evidence contains no raw log/image/binary and no actual credentials/user data. Screenshots of
one-time presentation use a clearly synthetic value, never a live issuance secret.

At the final audit, 53 entries differed from the continuation snapshot: 36 presentation source,
five ERB, three existing frontend tests, four owned design/reference docs, and five concurrent
security/state-machine docs not authored by this task. New test files are separate from this
snapshot count. The initial broader snapshot contains 8944 entries; a broad protected-source
prefix audit found 37 concurrently changed protected entries among 4062 entries. These counts
are source-hash observations, not proof of this task owning those changes. Controllers/models/
operations/jobs/values/queries/routes/stack config/DB and concurrent security diagrams were not
edited by this UI task. Earlier protected-attribute comparison and rendered payload assertions
are preserved in the implementation ledger/earlier evidence. Original actions/methods/hidden
fields, async handlers and prop declarations remain; no auth/session/CSRF/CSP/cache/host/props
contract or production dependency was introduced.

The final combined browser suite ran before the last issuance-notice tag correction; that
conditional branch was not covered by the admitted GET suite in either case. Its source status
semantics/type/build/lint were checked, but actual issuance remains unverified. Representative
rendering and source-wide foundation rollout are not page-by-page WCAG conformance evidence.

## Unverified, intentionally maintained and outside scope

Actual signup/provider/OTP transactions, one-time issuance and JS clearing lifecycle, all
nonempty/error/destructive states, remaining editions and legacy dispatch are unverified beyond
the recorded existing unit coverage. No screen reader, Firefox/WebKit, real iOS Safari or actual
400% browser zoom was available. Root-font enlargement and viewport reflow are not measured
browser zoom. No Japanese system fonts are installed; Japanese DOM/reflow was checked, but glyph
appearance is not certified. No WCAG/JIS conformance claim is made.

Offline styling remains blocked by its existing PWA CSP/nonce/cache delivery; only the native
retry and main landmark are verified. Base dashboard's normal synthetic session still failed the
selected-Persona prerequisite; the backend cause is not asserted and no bypass was added.
Server-owned names/menu props, host/stack discrepancies and Edge/regional repositories require
separate work. Auth TOTP's supplied hard-coded title `Totps` is retained rather than inventing a
new server naming contract in the View. Relay/plain/API/mailers, provider assets, dense tables,
Xper placeholders and third-party operational UI intentionally retain their distinct contracts.
