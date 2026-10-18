# Local UI normalization execution

Date: 2026-10-05 UTC. Branch: `feature`. Full HEAD:
`7de33215b055bc8f0f2721b86a04b428a049220e`. The worktree included unrelated staged,
unstaged and untracked authentication/secret/bootstrap work at the start and changed concurrently.
Results below include uncommitted presentation changes. No commit, branch, checkout, worktree,
external write, explicit migration, production request or actual IdP operation was performed.

Specification: [design guide](../docs/design.md). Scope/reachability:
[420 local view/page files including markers and added partials](../docs/reference/ui-view-inventory.md).
Source reading: [DADS ledger](../docs/reference/digital-agency-design-system.md).
Detailed decisions, commands, before/after conditions, exceptions and final status:
[implementation record](../docs/reference/ui-normalization-ledger.md).
The preceding named audit was not supplied or used.

## Completed checks

- `bun run test`: 93 files, 1114 tests passed. Existing submission/validation/navigation tests
  remained active. Subsequent targeted sign-out tests: 4 files, 21 tests passed.
- `bun run typecheck`: passed. `bun run build`: passed, 2369 modules. Only new package:
  dev-only `@axe-core/playwright`; production dependencies and delivery registry unchanged.
- Rails view/layout/stylesheet/editorial/nonce checks: 24 tests, 1846 assertions, no failures,
  errors or skips. Sign-out/admission/one-shot regression checks: 29 tests, 202 assertions passed.
- Final Playwright command (existing runner/config):
  `E2E_BASE_SERVICE_URL=http://base.app.localhost:3188/ E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3188/ node node_modules/playwright/cli.js test e2e/ui-erb-presentation.spec.ts e2e/ui-application.spec.ts e2e/ui-presentation.spec.ts --reporter=list --output=/tmp/umaxica-ui-normalization/final-verified`:
  **37 passed** in 24.8s. 10 actual anonymous application checks, 12 ActionView/Propshaft
  presentation fixtures, 15 React component fixtures. Fixture tests are not route-access evidence.
- Browser conditions: Chromium; 320/768/1024/1440 CSS px; light/dark/system under OS dark;
  reduced motion; actual root ja/en DOM; long text with root font at 200%; checkbox label activation;
  dialog Tab/Escape/return; skip Tab/Enter; scoped overflow; rendered axe A/AA tags with no exclusions.
  Additional anonymous GETs covered Base/Auth app/com/org and Help/Core-dev/Guid/Xper roots at 320px.
- `bin/rails runner -e test` with actual Erubi compiler compiled **122 ERB templates** after edits.
- Narrow UI/layout/landing/e2e oxlint, selected oxfmt checks, and `git diff --check`: passed.
- Actual palette contrast, focus and forced-colors observations are in the implementation record.

## Failures, recovery and remaining limits

The Page actions-without-title test reproduced a real dropped-action case before the fix.
The initial gallery showed a 36px button with 14px text and an axe keyboard-scroll region issue.
Long enlarged headings overflowed before wrapping was corrected. Independent ERB rendering
exposed a selector-specificity collision and a 4.35:1 text-link contrast failure; separate link
color and corrected selector priority resolved them. Retained browser checks cover both stacks.

Test-mode Rails cached a Vite manifest after rebuilding; root checks failed until the owned test
server restarted. A second overlap of build and browser verification reproduced this environment
condition. Final browser tests ran after the completed build and server restart, and passed.
A transient ERB theme comparison was corrected by waiting for rendering frames after theme selection.

Offline inline CSS is blocked by its existing PWA controller CSP, and its nonce helper yields an
empty nonce. A View-only nonce attempt did not fix it. Those style experiments were removed;
only a native main landmark remains changed. The test checks actual native retry GET/submit
behavior, not a 44px style that cannot reach the page. Fixing this requires separate CSP/cache
ownership work and is recorded as blocked, not visually complete.

Rails tests initially blocked on a concurrent pending migration, later passed as recorded above,
and a final repeat blocked on the newly added
`20261005063605_add_signup_completion_to_client_secret_issuances.rb`. No migration was run here.
The final independent ERB compilation and browser-renderer checks still completed.
Broader frontend lint found pre-existing avatar loop-variable/sign-out union-guard diagnostics and
concurrent untracked secret-page diagnostics; no authentication logic was changed to silence them.

Authenticated browser journeys, actual speech/screen readers, Japanese glyph coverage in this
Linux browser, all edition/state mixtures, Firefox/WebKit/real iOS and actual 400% browser zoom
remain unverified. Root-font enlargement and viewport reflow are not measured browser zoom.
No WCAG/JIS conformance or full page-specific redesign claim is made.

## Local artifacts and scope review

Anonymous screenshots/source snapshots are outside the repository at
`/tmp/umaxica-ui-normalization/`; they are temporary evidence, not permanent visual baselines.
SHA-256 prefixes for retained before/after pairs:

| Pair | Before | After |
| --- | --- | --- |
| Base app root, 1024×900 en/light | b7a1d0e9a5112d7e | a5cd8473746dc48a |
| Isolated gallery, 320px | b1fb9c50b168fd79 | bce3cfe8a9e1bd13 |
| Anonymous ERB logout fixture, 320px | c5da901392e27045 | 64c5dff81d0067c6 |
| Synthetic editorial new-entry fixture, 320px | 3fe5b3c6dae8b348 | c9d79df72e5dc4e5 |

Initial source hashes/status are in `baseline.json` and `status-before.txt`. A protected-attribute
comparison covered 140 changed tracked frontend files and 64 existing ERB templates. Reviewed
presentation exceptions were Page/link composition and display-only edition attributes; form
helpers, hidden inputs, methods, actions and behavior attributes were retained. Concurrent secret
presentation changes were identified separately rather than attributed to this task. The overall
git diff includes other authors' protected changes and is not evidence that this UI task edited
a controller/model/operation. This task did not edit those files, route/host/props contracts,
SurfaceChrome, CSP headers, cache policy, sessions or authentication state.
