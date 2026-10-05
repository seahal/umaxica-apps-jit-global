# UI normalization implementation and deviation record

Executed locally on 2026-10-05 against branch `feature`, HEAD
`7de33215b055bc8f0f2721b86a04b428a049220e`, with existing and concurrent uncommitted work.
The initial status and SHA-256 source snapshot are retained at
`/tmp/umaxica-ui-normalization/status-before.txt` and `baseline.json`; presentation sources were
copied into `before/` without checking out another commit. The named prior audit was not supplied
or read. Its candidate findings were treated as questions, not established defects.

The [canonical design guide](../design.md), [host/view matrix](ui-view-inventory.md), and
[official reading ledger](digital-agency-design-system.md) provide the specification and scope.
The inventory includes 418 original files and two added presentation partials, including markers
and non-HTML responses, not 420 independently reachable pages. Reachability and implementation coverage are separate columns.

## Delivery stages and user value

| Stage | Scope / affected cells | Actual change and user value | Verification / limit |
| --- | --- | --- | --- |
| A: baseline | Base/Auth app anonymous landing; Core dev, Help app, Guid net; common primitives; anonymous ERB logout fixture | Captured actual route screenshots and source snapshot; preserved existing operation tests. Primitive baseline measured 36px primary button, 14px label; axe identified an inaccessible scrolling table region. | Baseline screenshots outside repository; no authenticated baseline. Initial Rails tests blocked by a concurrent pending migration; later current tests ran successfully. |
| B: foundation | All established React surface imports; independent Propshaft HTML shells; Vite-owned ERB remains Vite-owned | Separate control/error roles, body text, focus, links, targets, bounded content, skip navigation. Ordinary header/consent controls no longer cover focused content. | Component/browser checks; actual anonymous roots; delivery/layout contract tests. No stack migration or props addition. |
| C: components | Forms, lists, dialogs and results using existing primitives | Bigger actual controls; clickable choice labels; underlined links; table keyboard scrolling; dialog vertical bounds; field relationships and contextual error announcement. | Existing Vitest behaviors retained; Page actions-without-title regression failed before fix and passed after; async error notification tests; browser dialog return and label activation. |
| D: composition | Landing; shared Auth result/logout; separate Base logout; session-limit manager; avatar settings; Edit org publishing forms/list/detail | Removed duplicate landing/editor gutters; calmer wrapping title scale; narrow decision pages; retained actions; explicit editorial labels/error references and local table overflow. | Anonymous live roots; common feature tests; editorial renderer tests. Editorial and logout fixtures do not prove authenticated route access. |
| E: rollout | Tracked React presentation pages/features, app/com/org shells; 15 existing thin content/dev/Guid roots; legacy wrappers; existing standalone continue documents | Applied body/link/error rules within each stack and reused existing Page/components. No new page, permission, registration option or invented matrix cell. Standalone continue documents get minimal local style without ordinary app chrome. | Per-file inventory distinguishes shared foundation, direct changes, legacy dispatch unknown and special exceptions. Foundation coverage alone is not a page-specific visual redesign. |
| F: review | Changed shared UI and representative roots | Long-title reflow fixed after browser reproduction; cookie close kept compact; error text separated from danger fills; duplicate imports cleaned. Archived contradictory design guidance. | Final build/type checks, actual authenticated representative GETs and isolated ceremonies below; full state/AT coverage remains unverified. |

## Deviation decisions

Evidence basis is independent of acceptance. C = source-confirmed, R = browser-rendered,
I = inference, U = unverified. WCAG references identify normative criteria, not proof of failure
or conformance. Prior source counts were not reused as current defect rates.

| ID | DADS section / normative reference | UMAXICA location | Rendered phenomenon | Visitor impact | Evidence basis / class | Applicability | Acceptance | Change | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UI-01 | Typography; Button; WCAG 2.5.8 AA distinct from 2.5.5 AAA | buttonStyles, TextField, Select, choice labels | Baseline gallery button 36px/14px; after default 48px/16px | Easier reading and activation | DADS 16px/44px recommendation; R | Ordinary UI, not provider assets | Adopt | Default 48px, small 44px; real label-inclusive choice target | 12 viewport/theme primitive states; label click | Implemented and component-verified; route-specific states U |
| UI-02 | Link text; WCAG 1.4.1 | TextLink, NavList, Page, page body links | At-rest underline computed in gallery | Destination discovery beyond color | DADS recommendation; R | Text/navigation links | Adopt | Persistent underline; original href/visit retained | Vitest links; computed underline | Implemented; representative verified |
| UI-03 | Color; WCAG 1.4.3 / 1.4.11 | theme.css, application.css | Necessary boundaries and error text now use independent tokens | More legible rejection and controls | Normative contrast plus UMAXICA palette; R | Actual active foreground/background pairs | UMAXICA adjustment | Zinc control boundary; red-700/red-400 errors; existing branded tints | Actual color conversion/contrast and axe | Measured representative app tint; other mixtures/state combinations U |
| UI-04 | Layout; Heading; WCAG 1.4.10 | Page, RootLanding, SurfaceLayout, Edit views | Smaller landing title and less double padding; long enlarged heading originally overflowed, now fits 320px | Main task visible earlier; content remains readable when enlarged | DADS layout guidance, UMAXICA widths; R | Landing/ceremony/form/list | UMAXICA adjustment | 28/42/56rem widths; wrapping title/action rows | 320/768/1024/1440 component checks; long text at 200% root font | Implemented; representative verified |
| UI-05 | Navigation/Header; WCAG 2.4.1 / 2.4.7 / 2.4.11 | Both document shells, SurfaceLayout, cookie controls | Skip first focus reaches main; footer controls no longer overlaid by fixed consent | Keyboard entry and focused content remain reachable | Normative criteria, DADS guidance; R | Existing HTML shells, not auto-post relay | Adopt / UMAXICA adjustment | Skip link; normal-flow header and named consent region | Live roots Tab/Enter; cookie computed static | Implemented; anonymous and representative authenticated routes verified |
| UI-06 | Input accessibility; WCAG 1.3.1 / 3.3.1 / 3.3.2 | Edit publishing new/edit/show; React Aria fields | Editorial title describes its visible error, error absent from accessible label | Understand which input failed without duplicate announcements | Normative relationships, DADS live-region restriction; C and renderer R | Server-provided field errors | Adopt | Explicit labels to existing IDs; describedby/invalid; field alert removed | Minitest rendered controls/payload attributes; isolated editorial DOM | Implemented; renderer and authenticated docs/app new-entry route verified; other editorial states U |
| UI-07 | Notification/Input accessibility; WCAG 4.1.3 | ErrorList, async avatar/admin forms | Initial error summary is readable content; async failures remain announced explicitly | Less unsolicited duplicate speech | DADS contextual restriction, WCAG state criterion; C; actual speech U | Existing sync versus async form feedback | UMAXICA adjustment | Optional internal `announce`; retained contextual form/service alerts | Summary/async/duplicate/empty-message unit tests | Implemented and DOM-tested; screen reader U |
| UI-08 | Table; WCAG 2.1.1 / 1.4.10 | Table and editorial list | Before axe scrollable-region-focusable violation; after keyboard target available | Wide data scrolls locally by keyboard | Normative keyboard/reflow; R | Existing tabular lists | Adopt / density adjustment | Focusable local wrapper; label where existing title available; dense 14px | Axe and computed page overflow | Implemented; gallery verified |
| UI-09 | Dialog accessibility; WCAG 2.1.1 / 2.4.3 | Dialog | Escape closes and returns to trigger; Tab stays inside | Predictable task recovery | DADS guidance; R | Existing modal use | Adopt | Bound height/vertical scroll; keep React Aria ownership | Browser focus/return; existing confirm tests | Implemented; isolated component verified |
| UI-10 | Corner/Elevation/Card | Existing cards, avatar silhouette, Dialog | Flat bordered gallery panels retained | Avoid unnecessary visual noise | DADS recommendation and UMAXICA judgment; R | Existing content grouping | Intentional difference | Keep role-based radii, no shadow added; title hierarchy strengthened | Existing card/dialog tests; screenshots | Maintained / implemented; not a universal radius replacement |
| UI-11 | Select usage | Former React Aria Select | Historical decision from initial normalization | Preserve established interaction | DADS native-select guidance; C | Initial implementation | Superseded by UI-30 | Native select now implements ordinary choice | Current native selection and submission tests | Historical; no longer current specification |
| UI-12 | Typography/Button; special documents | offline; shared/Palm continue; relay/plain/network/mailers | Offline and standalone continue retain simple independent documents | Retry/continue readable without app runtime; relay semantics protected | UMAXICA judgment; C; individual fixture R | Existing exceptional rendering only | UMAXICA adjustment / applicable exceptions | Offline main landmark only (visual styling blocked); minimal nonce-bearing continue style; relay untouched | ERB compilation; fixtures; operation/source review | Implemented exceptions; route/browser limits explicit |
| UI-13 | Header/Navigation/identity | SurfaceChrome::FAMILY_CHROME, Auth formal root heading, existing menus | Actual Auth headings remain Sign App/Com/Org; surface roles differ in existing data | Full family naming/menu consolidation cannot be completed here | Source-confirmed server ownership; R for headings | Existing approved props only | Out of scope / deferred | No server naming, props, permissions or fetch changes | Diff ownership review; root observations | Out of scope; requires separately authorized server/display-name decision |
| UI-14 | Layout/delivery | Guid net registry, README stack description, dev deny_all declaration | Guid root rendered; Core dev returned 200 in isolated test despite deny_all declaration | Documentation/host contract cannot be inferred from successful UI request | C versus actual R distinguished | Stack/security declarations | Out of scope / deferred | Record discrepancy; no host/registry/controller change | Local route/stack inspection; test-only GET | Blocked for backend/registry work; UI continued |
| UI-15 | Third-party provider branding | Existing social button CSS/assets | Provider authentication not exercised | Preserve recognizable provider controls | Official branding plus existing repo requirements; C, route U | Google/Apple/Entra only | Intentional difference | Generic ordinary button changes do not replace provider-specific CSS/assets | Source diff; official reading notes below | Maintained; full provider rendering U |
| UI-16 | Button/Layout; existing security contract | Rails PWA offline controller and existing inline CSS | Live style blocked by style-src-elem; nonce helper yields empty string; retry remains native 21px | Planned offline visual/target improvement cannot reach the document | R: console/CSP/computed target; DADS recommendation, not proven AA target failure | Offline cache and policy ownership | Out of scope / deferred | Main landmark added; styling experiments removed; no CSP/cache relaxation | Actual /offline GET/main/native submit; 44px attempt failed and recorded | Native recovery verified; visual improvement blocked |

## Continuation implementation

After the user resolved the test-environment blocker, the existing local tree was retained.
A second source/status snapshot was saved at `/tmp/umaxica-ui-normalization-continuation/`.
The following changes complete presentation rollout without altering server behavior:

| Stage / cells | Change and user value | Evidence / limits |
| --- | --- | --- |
| C/E: Auth app; Base app/com | Secret forms now use readable 48px inputs/actions; native constraints, generic rejection, names, hidden fields and handlers stay intact. One-time ERB reveal gets its own existing base_app Vite stylesheet, wrapping code, clickable acknowledgment and explicit continue/cancel hierarchy. | Native Secret empty/31/32/33/alphabet/zero/NUL partitions; one-time rendered payload test; synthetic reveal screenshots. Actual issuance, expiry and JS clearing journeys U. |
| C/D/E: app/com/org signup | Method choice/checkpoint/OTP/passkey/results use narrow Page hierarchy. Existing OTP autofocus and cancellation remain. Async passkey progress uses persistent native output; initial field summaries are related to the form without blanket live roles. | Existing success/failure tests; four ceremony fixtures at all four widths; unsupported passkey status regression. Actual provider/OTP ceremonies U. |
| D/E: independent com Identity | Existing forms/list/detail/result/confirm components use Page, related supporting descriptions and local table scrolling. Empty Secret lists expose the existing count. All 16 handlers and 27 prop declarations compared unchanged ignoring whitespace. | Existing 71 feature tests and three composition regressions; actual email and Secret inventory GETs. Nonempty/destructive branches retain unit coverage; full route journeys U. |
| D/E: Auth app TOTP and English settings | Missing TOTP page title reproduced and restored with named table and discoverable add action. Seven existing Japanese display keys added to each English regional bundle to resolve actual rendering failures. | Missing-heading regression failed before fix; admitted settings and identity GETs now pass in en/ja. Protected authentication-result copy unchanged. |
| D/E: Edit org and legacy ERB | Dashboard destination names disambiguate repeated audience links; list/form hierarchy and search controls align. Legacy passkey/logout wrappers normalized or delegated, without enabling routes or changing old scripts. | Actual dashboard/docs-app list/new GETs; ERB compilation. Legacy dispatch remains U. |
| F: final review | Kept distinct surface contracts, native versus Inertia navigation, contextual error semantics and provider styling. No new variant engine or server props. | Source snapshots/diffs and rendered checks; full matrix remains source coverage, not a conformance claim. |

| ID | DADS section / normative reference | UMAXICA location | Rendered phenomenon | Visitor impact | Evidence basis / class | Applicability | Acceptance | Change | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UI-17 | Heading/Table; WCAG 1.3.1 | Auth app TOTP index | Initial actual inventory lacked its supplied title; English settings also failed on missing display keys | Unclear purpose or unavailable settings page | Normative structure; UMAXICA copy ownership; C/R | Existing settings titles/attributes only | Adopt | Restore Page title/add action/named table; seven safe English display keys per regional bundle | Failing title regression then pass; actual en/ja GETs | Implemented / representative verified |
| UI-18 | Layout/Input/Heading | Independent com Identity | Consistent list/form/detail hierarchy and helper relationships; empty Secret count visible | Find edit/add actions and understand notification choices | DADS guidance / UMAXICA judgment; C/R | Existing com features and props | UMAXICA adjustment | Same specification implemented inside existing com ownership | 71 existing tests; three composition tests; actual inventory GETs | Implemented / representative verified |
| UI-19 | Button/Input; WCAG 2.5.8 distinct from AAA | Secret forms and standalone reveal | Real acknowledgment label and actions meet adopted 44px target; secret code wraps at 320px | Store and confirm safely without horizontal page overflow | DADS recommendation / UMAXICA judgment; R fixture | Existing one-time reveal only | Adopt / adjustment | Own stack stylesheet; label/actions/spacing only, original payload/clearing preserved | Rendered form regression and four synthetic browser widths | Implemented; actual issuance U |
| UI-20 | Notification; WCAG 4.1.3 | Async passkey panels | Persistent native output exposes progress; rejection remains separate alert | Discover progress without forced focus or field-error double notification | Normative contextual status; WHATWG output; C/DOM R, speech U | Existing asynchronous process messages | Adopt | Native output; handlers and status strings unchanged | Status-role regression and existing feature tests | Implemented / DOM-verified; speech U |
| UI-21 | Page/current context | Base app dashboard | Established-session test fixture still rejected selected Persona prerequisite | Cannot establish actual dashboard visual admission here | Observed server response; root cause U | Normal existing test setup | Out of scope / deferred | Retain shared Page/dashboard foundation; no auth/replica/controller change | Public fixture APIs and GET response | Actual dashboard GET unverified; backend prerequisite separated |

## Verification executed

Commands use the repository's existing runners. Production dependencies, frontend registry,
authentication callbacks and CI were not modified. The only added package is dev-only
`@axe-core/playwright`, needed to run an accessibility engine after rendering. Test server and
fixture setup are isolated by `Rails.env.test?`, use existing process-local feature/Turnstile
stub and outbound guard, and never contact real IdPs or send real messages.

```sh
bun run test
bun run typecheck
bun run build
bin/rails test test/unit/views test/integration/vite_asset_nonce_test.rb test/integration/erb_layout_preference_controls_test.rb test/integration/layouts_stylesheet_test.rb test/integration/surface_chrome_preference_controls_test.rb
bin/rails test test/integration/layout_rendered_title_smoke_test.rb test/integration/routes/edit_org_publishing_management_route_contract_test.rb
RAILS_ENV=test bin/vite build --mode=test --force
bin/rails runner -e test scripts/ui-test-server.rb
E2E_BASE_SERVICE_URL=http://base.app.localhost:3188/ E2E_AUTH_SERVICE_URL=http://auth.app.localhost:3188/ node node_modules/playwright/cli.js test e2e/ui-erb-presentation.spec.ts e2e/ui-application.spec.ts e2e/ui-presentation.spec.ts e2e/ui-authenticated-presentation.spec.ts e2e/ui-ceremony-presentation.spec.ts e2e/ui-secret-reveal-presentation.spec.ts --reporter=list --output=/tmp/umaxica-ui-normalization-continuation/final-browser
```

- Full Vitest after continuation: **98 files, 1126 tests passed**; no snapshots blindly updated or tests skipped.
- Typecheck and production build passed, **2369 modules**. Forced test-mode build also passed; its existing large-chunk warning was not suppressed by changing configuration.
- Final Rails checks in the two commands above: **25 tests, 1862 assertions**, no failures/errors/skips (17/1479 and 8/383). Earlier sign-out/admission/one-shot checks: **29 tests, 202 assertions passed**.
- Actual Rails Erubi compilation wrapped in a rendering method compiled **122 ERB templates**. Plain Ruby ERB is not a valid substitute for Rails block-helper syntax.
- Retained browser suite: **135 checks**: 10 actual anonymous application checks, 77 authenticated test-fixture GET checks, 12 isolated ERB-shell checks, 15 shared React gallery checks, 17 ceremony composition/native-boundary checks, four synthetic Secret-reveal checks. Final combined result: **135 passed in 1.4m**, recorded in the [continuation evidence](../../evidence/2026-10-05-ui-normalization-continuation-4R8C.md).
- The 77 admitted checks cover eleven GETs × seven conditions. English/light runs at 320/768/1024/1440px; Japanese/dark at 320px, English/system under OS dark at 320px, Japanese/system under OS light at 1440px. Authentication fixtures use public Client/Visitor/Operator token APIs and normal VisitorVerification issuance, with cookies in browser memory only. Own sessions are revoked afterward through the public API. Tracing is disabled for this file to avoid retaining credentials. These are established-session rendering checks, not evidence of login issuance.
- Root skip links, named main/title, actual overflow, axe A/AA tags, target sizes, keyboard focus, choice-label activation, dialog containment/Escape/return, reduced motion and long-text 200% root-font reflow were checked in their recorded scopes. No axe exclusions or coverage reductions.
- Narrow lint/format and source diff checks are recorded in the evidence; repository-wide unrelated diagnostics are not silently repaired by this task.

The earlier migration blocker was resolved outside this UI task; no migration was run here.
Test-mode Rails cached a Vite manifest after a build, causing script 404s and blank rendering.
A completed forced test-mode build and restart of the owned server resolved that environment
condition. This is not classified as a product layout defect. Actual settings GETs exposed safe
English display-key omissions; protected login-error text was not changed when an incomplete
verification fixture initially rejected admission. The normal verification fixture was corrected.

Measured actual app-tint palette contrast, light/dark: primary text/canvas **14.80/17.19**,
secondary/canvas **6.45/7.20**, error/surface **6.42/6.13**, error/canvas **5.37/6.54**,
primary action normal **5.25/5.29**, hover **6.83/7.53**, danger normal **4.77/5.23**,
hover **6.42/6.89**, control boundary/surface **4.83/6.75**, focus outline/canvas **4.38/7.15**.
Browser color conversion and WCAG luminance were used; these are representative measured pairs,
not all mixed/opacity/edition states. An ERB light-canvas link measured 4.35:1 before adjustment;
independent link color and corrected button selector specificity resolved it in retained tests.
Forced-colors emulation retained visible focus; this is not a real OS/screen-reader assessment.

Offline `/offline` returned 200 with native retry GET/submit/main behavior. Its nonce-less style
is blocked by the existing PWA CSP; the controller provides no usable nonce and the worker only
caches the document. View-only experiments were removed. Native retry measured 21px; no claim
of a styled 44px target or blanket WCAG failure based solely on native size is made. CSP/cache
changes needed for reliable styling are outside scope.

## Before/after and actual rendered coverage

Artifacts are retained outside the repository because evidence permits flat Markdown only.
They use anonymous or synthetic test records and do not contain real users or secret values.
The original directory is `/tmp/umaxica-ui-normalization/`; continuation screenshots are in
`/tmp/umaxica-ui-normalization-continuation/`. These are temporary evidence, not permanent
visual regression snapshots.

| Pair / conditions | Actual improvement | Evidence limit |
| --- | --- | --- |
| before/after Base/Auth app roots, 1024×900 en/light | Readable family hierarchy, less duplicate gutter, default action 36→48px | Actual anonymous GET, not login completion |
| before/after Core dev, Help app, Guid net roots | Bounded title/gutters using existing thin documents | Local aliases; no deployed-FQDN confirmation |
| gallery-before/after-320 | Readable fields/labels, underlined links and keyboard-scrollable table | Isolated common component |
| edit-new-before/after-320 | Persistent labels and explicit error recovery relationship | Matched reconstructed ActionView fixture; admitted new form also checked afterward |
| erb-out-before/after-320 | Independent Propshaft confirmation hierarchy and distinct action roles | Anonymous ActionView fixture; Base app Inertia logout GET independently admitted afterward |
| authenticated route screenshots named host/path/width/language/theme/OS | TOTP purpose/add action, com empty inventory count, Edit dashboard distinct destinations and usable narrow form | Actual admitted synthetic-session GETs; no full authenticated before-screen baseline exists |
| ceremony-{methods,checkpoint,otp,secret}-{width} | Clear purpose/next action and connected OTP form error at all widths | Synthetic composition; no IdP/OTP/Turnstile transaction |
| secret-reveal-synthetic-{width} | Wrapping code, clickable acknowledgment and clear continue/cancel | Synthetic ActionView document with its existing CSS injected; no live issuance/CSP or clearing lifecycle claim |

The browser is Chromium; no Firefox/WebKit, real iOS Safari, real screen reader or measured 400%
browser zoom was available. Root-font enlargement and 320px viewport reflow are explicitly not
browser-zoom measurements. The Linux system has no Japanese font coverage; Japanese DOM,
relationships and reflow were checked, but captured glyph appearance cannot certify Japanese
visual typography. Business validation, disabled and submit behavior remain unchanged. Existing
public-interface tests retain their own partitions; Secret native input adds empty, 31/32/33,
invalid alphabet, zero and NUL cases without adding business rules. No WCAG/JIS conformance
claim is made from this representative scope.

## Provider-source check

Read on 2026-10-05: [Google branding](https://developers.google.com/identity/branding-guidelines)
(size, color, font, padding, logo and equal prominence; displayed update 2026-07-07),
[Apple Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple/)
(button title, dimensions/margin, supplied artwork; official JSON read because HTML required JS;
visible history 2022-09-14), and [Microsoft branding](https://learn.microsoft.com/en-us/entra/identity-platform/howto-add-branding-in-apps)
(account labels, logo and imagery; displayed update 2023-12-15). Distinct provider CSS/assets
remain. Source review does not certify every existing button state.

## Final critical review and outcome

1. Surface permission, auth state, cancellation, native/document versus Inertia navigation and
   independent logout payloads remain distinct. Normalization introduces no option or permission.
2. Shared foundations align independent stacks and editions; admitted Base/Auth/Com/Edit samples
   confirm representative continuity. Legacy dispatch and all state/edition combinations remain U.
3. Existing Page/primitives and independent com features are reused; no giant variant engine,
   extra props, cross-stack runtime, fetch or persistence was introduced.
4. Long heading/code reflow and local table scrolling are checked. Flow consent increases page
   length while removing overlap; mobile primary controls remain visible in representative renders.
5. Initial summaries, field errors and asynchronous output have separate semantics; existing
   autofocus remains. Dialog returns focus. Actual speech and provider interactions remain U.
6. Canonical specification, per-file matrix and decisions now describe the implementation, with
   archived guidance retained as history. Counts distinguish source coverage from route evidence.
7. This task edited no protected server/route/props/auth/session/CSP/cache source. Concurrent
   protected changes are present and must not be attributed to this presentation work.
8. Representatives show clearer task purpose, discoverable permitted actions and readable error
   relationships; foundation rollout does not certify every page/state as visually reviewed.

**Implemented and verified:** shared foundation and composition in the recorded unit/browser
scopes; anonymous entry/native offline recovery; eleven admitted authenticated GETs; rendered
editorial and Secret payload preservation. **Implemented, unverified:** other admitted states,
remaining edition combinations and legacy dispatch; one-time actual issuance/clearing and full
signup/provider journeys; Palm standalone route. **Not implemented:** changes requiring new
server identity/menu data, and offline visual delivery repair; these are separated below rather
than counted as presentation completion. **Intentionally maintained:** relay/plain/API/mailers,
provider styling, special offline behavior, dense data, Xper placeholders and vendor operations.
**Out of scope / blocked:** server-driven family naming/menu props (including the supplied hard-coded TOTP title `Totps`), host/registry discrepancies,
offline CSP/cache styling, Base dashboard selected-Persona test prerequisite, Edge/regional work.
Actual AT, browser zoom and Japanese font assessments remain unverified, not implementation
successes. Whole-product WCAG/JIS conformance and exhaustive journey coverage are not declared.

## Foundations acceptance refinement

The user accepted all eight foundations proposals on 2026-10-05. The same HEAD/worktree was
retained. This continues the earlier implementation; historical findings above are not rewritten
as if the new rules were already present. No production dependency or runtime configuration was
added. The source reread is recorded in the DADS ledger.

| ID | DADS section / normative reference | UMAXICA location | Rendered phenomenon | Visitor impact | Evidence basis / class | Applicability | Acceptance | Change | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UI-22 | Color: focus; WCAG 2.4.7 separately from 2.4.11/2.4.13 | theme.css, application.css, standalone ceremony style, Apple focus | Black 4px outline with Yellow-300 inner band; choice label carries hidden input focus | Locate the active control in both themes | DADS palette specification; R common fixture | Ordinary focus; forced colors uses system colors; provider appearance retained | Adopt / platform adjustment | Immediate outline; label :has focus; forced-color Highlight without shadow | Light/dark computed style; forced-color navigation; retained keyboard regressions | Implemented / representative verified; provider runtime states U |
| UI-23 | Typography: size and density; WCAG 1.4.4/1.4.12 | Field primitives, notification preferences, OTP/TOTP support, flash output, footer, Xper badge | Synthetic preference explanation 12→16px; Xper phase badge 12→14px | Read conditions and choices without relying on small text | DADS baseline; R fixtures, C rollout | Main UI/support 16px; supplementary/dense content 14px | Adopt / bounded density | Remove readable text-xs; keep decorative tick; native constraints unchanged | Existing 1126 tests; browser explanation; Xper CSS before/after fixture | Implemented / representative verified; every page's small-text state U |
| UI-24 | Icons: labels/containment/contrast; WCAG 1.1.1/4.1.2 | NavList, Page up link, Checkbox, cookie dismissal | Navigation arrow excluded from accessible name and underlining, inside same link | Hear one useful destination name and activate the complete link | DADS specifications / UMAXICA classification; C/R | Decorative arrows/check mark; existing named icon-only close | Adopt / documented icon-only exception | Explicit role/name/target rules; decorative glyph treatment retained rather than adding icons | Arrow/name/target checks; existing cookie 44px and axe tests | Implemented rules / representative verified; speech U |
| UI-25 | Layout: reading/order/liquid; WCAG 1.4.10 | InfoPage, Page description, shared article, existing width variants | Long ja/en paragraphs fit at 320–1440px and enlarged root font | Follow prose without narrowing useful tables/forms | DADS guidance / UMAXICA measure; R fixtures, C article | Reading prose; data widths and local table scroll retained | UMAXICA adjustment | Independent ui-prose 65ch / ja 40em within Page; no automatic 768px transition | Eight prose language/width states; 200% root font plus spacing overrides | Implemented / representative verified; article route dispatch U |
| UI-26 | Link text: states/purpose; WCAG 1.4.1/1.4.3 | TextLink, NavList, Page, literal body links, independent ERB stylesheet | Hover strengthens underline; state tokens have measured text contrast | Discover destinations and receive feedback without layout movement | DADS guidance / UMAXICA palette; C/R | Text links; wordmark/provider/actions retain their role | Adopt / palette adjustment | 1→2px underline; purple visited / orange active; original href/visit untouched | Hover computed style; measured state palette; existing document/Inertia tests | Implemented / representative verified; actual native visited-history appearance U |
| UI-27 | Spacing: relationships; Typography paragraph separation | Field groups, DescriptionList, Page/ERB ui-page, ui-prose | Prose gap 12→36px en / 40.8px ja at default size; page sections both 32px | Distinguish related support from a new subject | DADS recommendation / UMAXICA scale; R | Long prose versus local field/action groups | Adopt / context adjustment | 1.5lh prose separation; field 8px; two-column description gutter 32px | Prose geometry and spacing/resize axe; retained layout regression | Implemented / representative verified |
| UI-28 | Corner shapes: role/size | NavList and canonical guide | Ordinary navigation row computes 6px corners | Same-sized controls carry consistent shape cues | DADS guidance / UMAXICA role choice; C/R | Controls/rows 6px; dialogs 8px; cards/tables 12px; avatar/cookie exceptions | UMAXICA adjustment / intentional differences | Nav rows rounded-md; document actual retained roles | Computed row radius; retained viewport checks | Implemented / representative verified; every retained radius U |
| UI-29 | Elevation: boundary/dark/forced colors; WCAG 1.4.11 necessary information | Dialog, Select Popover, theme.css | Light dialog edge against composited canvas backdrop 1.44→3.12:1; surface edge 10.43:1; dark 7.56 / 6.75:1 | Identify dialog bounds without relying on shadow | DADS guidance / normative contrast; R modal, C popover | Necessary overlay boundaries; decorative dividers remain distinct | Adopt / dark-mode adjustment | Used overlay-boundary token; no new shadow/elevation/function | Actual CSS canvas color conversion and inner/outer contrast assertions; Escape/return | Dialog implemented / representative verified; popover-specific composition U |

The additional browser fixture uses real presentation components with synthetic props; it is not
an authentication journey or admitted application route. Twelve additional checks cover the
foundation behaviors above. A full combined run passed **147 checks**, including the unchanged
135-check scope, with no skips/retries/axe exclusions. The test for preference payload uses the
actual visible label, preserving the React Aria hidden native input, and confirms unchecked `0`
versus checked `0,1` without submitting. All existing action/method/hidden payload/handler/props
and stack contracts remain with their owners.

Canonical specification, source ledger and inventory link this refinement. The inventory remains
**420 files / 420 rows**, with no production view added. Xper's isolated stylesheet/placeholder
role is intentionally retained; only its small phase metadata increased to 14px. Mailers are
outside this browser-HTML scope. No auth/session/controller/model/routes/props/CSP/cache/stack
or persistence change is authored here; pre-existing/concurrent work must remain separate.

**Implemented and verified:** all eight decisions within the source/component and representative
browser scopes above; recorded anonymous/admitted GET regressions. **Implemented, unverified:**
other route/state/edition combinations, provider-focus runtime, native visited-history appearance,
and article/popover-specific admission. **Intentionally maintained:** dense 14px data, existing
avatar/cookie/provider shapes, mailers, Xper layout, relay/plain/offline exceptions. **Outside
scope / blocked:** earlier offline delivery and dashboard prerequisite, server-owned naming/menu
information, Edge/regional work. Actual AT, Japanese glyph appearance, real iOS and native 400%
zoom remain unverified. The [acceptance evidence](../../evidence/2026-10-05-ui-foundations-8F4D.md)
records commands, failed baselines, final results, and the unrelated TOTP lint diagnostic.


## Components acceptance refinement

The user accepted all nine proposals and required t-wada red–green–refactor cycles. Native
HTML takes precedence; ERB uses Rails helpers and existing delivery. Baseline hashes of all
8984 source paths and status are `/tmp/ui-components-baseline.json` and
`/tmp/ui-components-start-status.txt`. Shared gallery screenshots were captured at 320/1440px
before changes. These are synthetic component evidence, not admitted application paths.

| ID | DADS section / normative reference | UMAXICA location | Rendered phenomenon | Visitor impact | Evidence basis / class | Applicability | Acceptance | Change | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UI-30 | Select usage | Select; preferences/admin/recovery callers | Native combobox uses existing options/values | Familiar selection and fewer bespoke interactions | DADS native OS guidance; R component | Ordinary single choice | Adopt | Native select/options; parent transport unchanged | Disabled stored choice, required/disabled, FormData, empty/zero/NUL and existing preference submissions | Implemented / component-verified; native OS picker beyond Chromium U |
| UI-31 | Input usage/accessibility; Textarea; WCAG 1.3.1 / 3.3.2 | TextField; AvatarForm; publishing forms | Conditions precede input and error follows it | Understand restrictions before submitting | DADS recommendation; C/R | Existing supplied constraints only | Adopt | Grapheme/byte copy, Rails describedby, JSON format help and summary error | Red helper-order/moniker tests, unchanged validation and form payload tests | Implemented; route/state coverage in evidence |
| UI-32 | Date picker usage/accessibility | BirthdateFieldset | Persistent example and readable separate fields reflow | Enter known date without opening a calendar | DADS direct-entry guidance; R component | Existing three number inputs | UMAXICA adjustment | Visible examples/spacing, native attributes unchanged | Label/description and exact attributes; four widths, 200% root text | Implemented / component-verified; actual signup submission U |
| UI-33 | Table usage/accessibility | Table; AdminRecordList; publishing index; independent CSS | Default 16px versus explicit Dense 14px; scroll edge cue | Read ordinary data and discover additional columns | DADS density/scroll guidance; R component | Existing tables; Dense administrative/editorial only | Adopt / adjustment | Strong header, local scrolling/keyboard/native scrollbar | Red font/scroll-cue checks, green keyboard/reflow/axe | Implemented / representative verified |
| UI-34 | Card usage/example | Card | Titled subject is named region with stronger border; plain panel stays div | Understand grouping without unnecessary landmarks | DADS subject/boundary specification, UMAXICA panel distinction; C/R | Existing card headings | UMAXICA adjustment | Heading association and role-specific boundary | Red semantic card tests; rendered fixture/axe | Implemented / component-verified |
| UI-35 | Header, navigation, page navigation | ERB layouts; SurfaceLayout; AdminRecordList | Purpose names follow ja/en rather than fixed English | Identify navigation areas consistently | DADS guidance / WCAG 2.4.6; C/DOM R | Existing allowed destinations only | Adopt | Explicit Rails translations and view-only metadata | Red Japanese footer test; layout/route checks in evidence | Implemented; destination contracts retained |
| UI-36 | Button accessibility | buttonStyles; AdminConfirmation | Pressed opacity previously 0.9 after animation; now 1; disabled reason visible | Preserve readable states and explain unavailable operation | DADS contrast/disabled guidance; R component | Ordinary actions, excluding providers | Adopt | Full opacity existing palette; acknowledge/processing explanation | Red settled-opacity and disabled-description tests; native disabled/payload regression | Implemented / component-verified; real administrative mutation U |
| UI-37 | Notification banner / notice block / progress; WCAG 4.1.3 | AdminNotices; existing field/status feedback | Mixed group uses one highest-urgency live region | Avoid competing announcements while retaining async result notification | Contextual normative status requirement plus DADS guidance; DOM R, speech U | Existing administration result notices | UMAXICA adjustment | One group, decorative tone icon; text/handlers unchanged | Red grouping tests; existing async errors/passkey checks; axe | Implemented / DOM-verified; assistive speech U |
| UI-38 | Language selector; Adobe localization | DocumentLocale; SurfaceLayout; UiGallery | Aria locale follows document language rather than browser default | Built-in interaction language matches page | UMAXICA locale authority / Adobe API; DOM R | Existing Rails document language | Adopt | Existing I18nProvider and lang observer; no persistence change | Red locale-provider test; document update/ja-en fixtures | Implemented / component-verified; full locale preference journey U |

No accordion/disclosure, calendar, tabs, carousel, mega menu or other absent feature was added
because the catalog includes it. Native details/summary is preferred when a real folding task
arises. Five-or-fewer radio advice was considered; existing variable option sets and disabled
stored values retain native select rather than inventing options or changing the preference
interaction contract. Birthdate keeps existing number inputs despite DADS text-entry examples:
changing browser type/validation is outside this visual adjustment. Deprecated bottom navigation
and scroll-to-top components were not introduced. Plain errors, relay, offline and provider
exceptions retain their existing contracts.

The [current-session evidence](../../evidence/2026-10-05-ui-components-T8D2.md) separates
actual routes from renderer/component fixtures and passing checks from failures/blockers.
Earlier totals above remain historical; they are not this acceptance run's results.
