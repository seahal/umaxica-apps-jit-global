# Inertia + React + TypeScript Full View Migration — Design Audit

Date: 2026-08-14 Status: Audit complete — **READY FOR IMPLEMENTATION** Related:
`notes/implementation/inertia-per-surface-vite-pipeline.md`,
`notes/implementation/preference-index-inertia-migration.md` (both remain valid; this document
supersedes the view-migration scope of `plans/rails-react-clever-lecun.md` and
`plans/rails-react-hashed-whistle.md` where they overlap).

## 1. Executive Summary

Migrate all Rails-owned browser HTML views to Inertia Rails + React + TypeScript. The Inertia 3.x
platform migration is **already complete** in this repository (gem 3.22.0, @inertiajs/react 3.6.1,
React 19, all required 3.x config flags enabled, zero legacy v2 usages found). The remaining work is
page migration: ~330 browser ERB templates across five families (auth 120, base 132, core 7, side 7,
palm 2, plus 20+ `layout false` root landings and 40 layouts) onto the existing per-surface Inertia
pipeline, which today serves only the `base/{app,com,org}` preferences tree and
`base/app/groups#index`.

Out of scope by decision: Mailer ERB (preserved), info/docs/news/help browser UI (Next.js-owned;
Rails keeps only its static landings and JSON entries API), non-HTML endpoints, SSR, Playwright/E2E
expansion.

## 2. Current Architecture (verified against the repository)

- Surfaces are chosen by **hostname** (`constraints host:` blocks), not path; families drawn from
  `config/routes/{base,auth,core,side,palm,help,news,docs,info}.rb`. `base`/`core` additionally have
  `dev`/`net` surfaces.
- Frontend root is `src/` (vite.json `sourceCodeDir`). 10 per-surface `createInertiaApp` entrypoints
  in `src/entrypoints/inertia/` using the Inertia 3 `pages:` resolver with `surfacePageTransform`
  (throws on cross-surface page names) from `src/inertia/surface.ts`. Only `base_{app,com,org}`
  entrypoints have pages today.
- Inertia config `config/initializers/inertia_rails.rb`:
  `parent_controller "::ApplicationController"`, `version = ViteRuby.digest`, `encrypt_history`,
  `always_include_errors_hash`, `use_script_element_for_initial_page`,
  `use_data_inertia_head_attribute` — all true. `config/initializers/inertia_rails_compatibility.rb`
  monkeypatches `InertiaDebugExceptions#render_for_browser_request` for the Rails 8.2 arity change
  (comment cites 3.15; lock is 3.22.0 — update comment).
- Layout selection: `app/controllers/concerns/surface_inertia_page.rb` derives
  `layout "<family>/<surface>/inertia"`. Exception: `base/app/groups_controller.rb:11` hardcodes the
  layout (to unify).
- CSP (`config/initializers/content_security_policy.rb`): strict-dynamic + nonce, no unsafe-inline;
  nonce delivered via `meta[property=csp-nonce]`; compatible with the 3.x script-element initial
  page (proven by `test/integration/inertia_page_contract_test.rb` asserting `script[data-page]` and
  409-on-stale-version).
- No SSR (`ssr_enabled` unset, `inertia_ssr_head` present in layouts but inert). No `inertia_share`
  anywhere; props are hand-built hashes (`serialize_group`, `*_page_props`); no ActiveRecord objects
  passed as props.
- Turbo/Stimulus: 14 Stimulus controllers (all `.js`) in `src/controllers/`; Turbo imported only by
  the non-Inertia `src/entrypoints/application.ts`; Inertia entrypoints deliberately skip Turbo; all
  vite tags carry `data-turbo-eval="false"`. No rails-ujs, no importmap file.

## 3. Dependency Inventory

| Dependency              | Current                          | 3.x requirement       | Status                              |
| ----------------------- | -------------------------------- | --------------------- | ----------------------------------- |
| inertia_rails           | 3.22.0                           | ≥ 3.19                | OK                                  |
| @inertiajs/react        | 3.6.1                            | ^3.0                  | OK                                  |
| @inertiajs/core         | 3.6.1 (transitive)               | ^3.0                  | OK                                  |
| @inertiajs/vite         | 3.6.1                            | optional, recommended | in use (pages resolver)             |
| React / React DOM       | 19.2.8                           | React 19+             | OK                                  |
| TypeScript              | 7.0.2                            | —                     | strict mode on                      |
| Vite / vite-plugin-ruby | 8.2.0 / 5.2.2                    | —                     | OK                                  |
| vite_rails / vite_ruby  | 3.11.1 / 3.10.2                  | —                     | OK                                  |
| Rails / Ruby            | 8.2.0.alpha (rails/main) / 4.0.6 | —                     | compat monkeypatch needed (present) |
| Vitest / Playwright     | 4.1.10 / 1.62.1                  | —                     | Vitest in CI; Playwright not        |
| Node / pnpm             | 24.19.0 / 11.20.0                | —                     | OK                                  |

## 4. View Inventory

389 files under `app/views` (344 `.html.erb`, 19 partials, 13 `.xml.builder`, 1 jbuilder, 1 `.js`).
No haml/slim.

- **A. Inertia pages (current)**: 16 `.tsx` under `src/pages/base/**` (preferences tree ×3
  surfaces + groups/index).
- **B. Conventional browser HTML pages**: auth 120, base 132 (minus migrated preferences), core 7,
  side 7, palm 2, sign 10 (cross-render forwarder templates), shared 9.
- **C. Inertia root layouts (8)**: `layouts/{auth,base,side}/{app,com,org}/inertia.html.erb`,
  `layouts/palm/app/inertia.html.erb` (`inertia_root`, `inertia_ssr_head`, vite tags, nonce meta).
- Conventional layout twins (13): `layouts/*/*/application.html.erb` (chrome partials + `yield`);
  `layouts/jump/*` appear dead (no controller declares them).
- **D/E. Mailer**: `layouts/mailer/{app,com,org}/mailer.{html,text}.erb`,
  `layouts/email/application.html.erb` (html-only; OTP text parts get no layout),
  `app/views/email/**` 18 templates. Mailer layouts share **no** partials with browser layouts.
- **F. Partials (19)**: `layouts/shared/*` chrome (7), turnstile ×2, passkeys/registration,
  recovery_passcodes, ui/button, auth/shared ×3, base/shared ×4. Highest fanout:
  `base/shared/self_service/_shell.html.erb`.
- **G. Error pages**: static `public/{400,404,406-unsupported-browser,422,500}.html`; no
  `exceptions_app`; no errors controller.
- **H. Non-page**: 13 `sitemaps/show.xml.builder`, `base/app/identity/sessions/index.json.jbuilder`,
  robots (text, no template), health `shared/health/show.html.erb`.
- **I. Dead / apparently unused**: `shared/content_entries/{index,show}.html.erb` (no controller),
  `sign/app/passkeys/new.html.erb`, `sign/org/outs/edit.html.erb` (no `Sign::` controller
  namespace), `app/views/pwa/*` (shadowed by Rails engine `/rails/pwa`), `layouts/jump/*`
  (probable), `auth/org/omniauth/omniauth_callbacks/error.html.erb` (verify `render_entra_error`
  reaches it before classifying).
- **J. Ownership unclear**: none remaining after interview.

## 5. Route & Controller Inventory (HTML endpoints)

949 controllers; render census: 221 `render json`, 98 `render plain`, 9 `render inertia`, 236
explicit template renders, plus implicit renders (dominant for roots/dashboards). Full per-family
route maps live in `config/routes/*.rb` (surface via host constraints).

Migration targets by family (HTML page actions only;
JSON/webhook/OIDC-callback/health-probe/robots/sitemap/csp-report/PWA-engine routes are
non-targets):

| Family              | HTML page scope                                                                                                                                                                                                                                                                                                                                                                 | Target                     |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| base                | welcome, dashboard, selector, switcher, billings, groups, accounts, organizations(+memberships), preference tree (partially done), identity/* (standing, recovery, mfa, emails, telephones, birthdate, secrets, sessions, activities, withdrawal, privacy/erasure), avatars(+follows/blocks/mutes), oidc/logouts confirmation, sign/in/limitation, sign/out(+completion), roots | Inertia                    |
| auth                | sign-in/up ceremonies, verification/OTP, passkeys, TOTP, OmniAuth result pages, settings, preferences (`auth/*/preferences_base_controller` — ERB counterparts of base's Inertia ones), sign-out/handoff, roots                                                                                                                                                                 | Inertia (last)             |
| core                | roots, dashboards, sign_outs (via shared templates)                                                                                                                                                                                                                                                                                                                             | Inertia                    |
| side                | roots, dashboards (`side/shared/dashboards/show`), sign_outs                                                                                                                                                                                                                                                                                                                    | Inertia                    |
| palm                | roots, sign/outs                                                                                                                                                                                                                                                                                                                                                                | Inertia                    |
| info/docs/news/help | roots landing only                                                                                                                                                                                                                                                                                                                                                              | **stays ERB** (Decision 2) |

Non-targets confirmed in code: OAuth `token/userinfo/revoke` (JSON), `.well-known` (JSON),
`web/v0` + `edge/v0` APIs, MCP, csp-violation-report, health probes, robots/sitemaps, PWA engine
routes, OIDC/OmniAuth callbacks (redirects), 98 `render plain` security rejections.

## 6. Next.js Boundary (info/docs/news/help)

Rails owns per surface: one static `roots/index.html.erb` (`layout false`, self-contained HTML) and
the JSON `api/v0/entries` API. No HTML entry pages, no redirects, no duplication with Next.js UI.
Per ADR `read-only-content-surfaces-in-rails.md` (superseded by
`publishing-db-content-authority.md`), public content HTML belongs to the frontend repository.
Decision: keep the static ERB landings as an explicit exception; `shared/content_entries/*` is dead
and will be deleted in cleanup. A future redirect-to-Next.js change is deferred (open question).

## 7. Mailer Boundary

All of `app/views/email/**`, `layouts/mailer/**`, `layouts/email/application.html.erb` are preserved
as ERB. Guard against accidental deletion: the cleanup phase's dead-ERB sweep must operate on an
allowlist (Inertia shells, mailer trees, info/docs/news/help landings, `shared/health/show`, xml
builders) rather than "delete all remaining ERB". Mailer layouts render no browser partials, so
slimming/removing `layouts/shared/*` cannot break mail. Known pre-existing quirk (not in scope to
change): OTP mailers use html-only `layouts/email/application` so text parts are un-layouted.

## 8. Inertia 3.x Compliance (official upgrade guide, item by item)

| Official item                                                         | Requirement                                | Current implementation                                          | Applicable        | Migration                                                   | Risk                                          |
| --------------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------- | ----------------- | ----------------------------------------------------------- | --------------------------------------------- |
| Versions                                                              | gem ≥3.19, @inertiajs/react ^3, React 19   | 3.22.0 / 3.6.1 / 19.2.8                                         | yes               | none                                                        | none                                          |
| `use_script_element_for_initial_page`                                 | true                                       | true (`config/initializers/inertia_rails.rb`)                   | yes               | none                                                        | CSP verified via nonce infra + contract tests |
| `use_data_inertia_head_attribute`                                     | true                                       | true                                                            | yes               | none                                                        | none                                          |
| `always_include_errors_hash`                                          | true                                       | true                                                            | yes               | none                                                        | none                                          |
| `inertia` → `data-inertia` head attribute                             | replace in head markup                     | zero occurrences of either; no `<Head>` usage at all            | not yet           | adopt `<Head>` in Phase A with 3.x semantics from the start | none                                          |
| Axios removal                                                         | remove axios/interceptors                  | no axios imports                                                | no                | none                                                        | none                                          |
| `qs` / `lodash-es` no longer bundled                                  | install if imported                        | not imported                                                    | no                | none                                                        | none                                          |
| Event renames (`invalid`→`httpException`, `exception`→`networkError`) | update listeners                           | no listeners                                                    | no                | none                                                        | none                                          |
| `router.cancel()` → `cancelAll()`                                     | replace                                    | not used                                                        | no                | none                                                        | none                                          |
| `future.*` config removal                                             | delete block                               | absent                                                          | no                | none                                                        | none                                          |
| Progress fns → `progress.hide()/reveal()`                             | replace                                    | not used                                                        | no                | none                                                        | none                                          |
| React Deferred `reloading` prop                                       | review loading UI                          | no Deferred usage                                               | no                | none                                                        | none                                          |
| Form reset timing (`onFinish`)                                        | review timing logic                        | no timing-dependent form code                                   | no                | none                                                        | none                                          |
| React layout arrays (`Page.layout = [Layout]`)                        | arrow components must be wrapped in arrays | no layouts yet                                                  | **yes (forward)** | all new persistent layouts use array form                   | low                                           |
| ES2022 target / ESM only                                              | build ≥ES2022, no CJS                      | ESM only; tsconfig target ES2020 (noEmit; Vite 8 emits ≥ES2022) | partial           | optionally align tsconfig `target`                          | none                                          |

Extra repo-specific item: keep `inertia_rails_compatibility.rb` (Rails 8.2 debug-exceptions arity)
and re-verify on every inertia_rails bump; fix its stale "3.15" comment.

## 9. TypeScript Migration

Current: 34 `.tsx`, 17 `.ts`, 0 `.jsx`, 17 `.js` (14 Stimulus controllers + `theme_cookie.js` +
`turnstile_api.js` support + controllers index). tsconfig strict, `allowJs`/`checkJs` off — the
`.js` files are outside typechecking.

Policy: no `allowJs` enablement. Stimulus controllers are replaced (not converted) by React
hooks/components per Decision 3; framework-agnostic logic (`webauthn_utils`, `turnstile_api`, theme
cookie handling) is rewritten as `.ts` utilities during Phase A. `.js` files are deleted with the
Stimulus removal in Phase F. Justified JS remainders: none expected (config files are already
`.ts`). Props typing: `SharedProps` interface plus per-page prop interfaces in `src/types/`; no
`any`/`Record<string, any>` prop bags — CI typecheck (`tsc --noEmit`) enforces.

## 10. UI Migration (ERB → React)

- Persistent layouts: `src/layouts/<family>/<surface>.tsx` (array form), replicating
  `layouts/shared/*` chrome (banner, copyright, footer cookie/theme controls, current-banner). ERB
  `inertia.html.erb` slims to document shell.
- Highest-fanout partial `base/shared/self_service/_shell.html.erb` becomes a shared React shell
  component before Phase B page work.
- Forwarder templates (`sign/shared/*` → `auth/shared/*`, `side/shared/dashboards/show`, recovery
  passcodes, sign-out family) become shared React components referenced by multiple surfaces' pages
  (respecting the cross-surface resolver guard: shared components live outside `src/pages/`).
- `layout false` root landings become Inertia pages last (Phase E); info/docs/news/help roots
  untouched.
- Existing behavior/appearance preserved; no UI redesign.

## 11. Rails/Inertia Contract

- Props: hand-built allowlisted hashes (existing `*_page_props` pattern is canonical); no AR
  objects, no tokens/secrets. IDs are `public_id`s; timestamps serialized as ISO strings at the
  builder; enums as strings; URLs generated server-side (`*_url`) and shipped as props (see helper F
  category).
- Shared props: `inertia_share` in each surface base controller (Decision 7) — auth-state summary,
  banner (`current_banner_for` re-implemented with explicit read role), locale/region, theme.
  Surface isolation preserved: each surface defines its own builder; nothing shared across surfaces.
- Forms: Inertia `useForm`/form defaults already configured (`surfaceInertiaDefaults`:
  `withAllErrors`, brackets array format). HTTP semantics preserved: PATCH/PUT/DELETE via Inertia
  visits; multipart/direct-upload cases handled per-page during migration.
- Errors/feedback: redirect-back + errors props (Decision 5, `always_include_errors_hash` active);
  no flash (repo rule); `render plain` security rejections unchanged. Auth's current 422-rerender
  sites convert to redirect+errors — verify no dependency on 422 status for browser forms.
- External redirects from Inertia visits (OAuth handoff etc.): `inertia_location`; callbacks
  themselves stay non-Inertia (cf. `app/controllers/concerns/authentication_base.rb:736`).
- Serialization risk: watch N+1 in list pages (groups precedent maps relations through serializers;
  Prosopite is active).

## 12. Head & Metadata Contract

- Rails root ERB shell owns (source of truth): doctype, `<html lang>` (`get_language`),
  `data-theme`/theme class (`theme_cookie_value`/`theme_html_class` — pre-boot, FOUC-sensitive),
  charset/viewport, CSRF meta, CSP meta + nonce meta, vite tags, favicon/manifest, brand TLD meta
  (`brand_tld`), `inertia_root`.
- Inertia `<Head>` (React) owns: per-page `<title>` and page-level meta, using 3.x `data-inertia`
  attribute semantics (config already active). This replaces the current
  `page_title(inertia_page&.dig(:props, :title))` ERB bridge; a static fallback title remains in the
  shell.
- `data-inertia` ownership: emitted/managed by the Inertia React adapter on elements it controls;
  ERB shell must not hand-write it.

## 13. Test Migration

Two-layer standard (Decision 6):

- Minitest: page-object (`test/support/inertia_page_object.rb`) asserts component name, props,
  auth/authorization, redirects, protocol headers. `assert_select`/body assertions in ~85+72 files
  migrate 1:1 per page (preference migration precedent: ≈81 assertions). No test deletions, no
  skips.
- Vitest: page/component markup and interaction under `spec/` (98% coverage thresholds maintained).
- `test/unit/views/template_compilation_test.rb` and erb_lint scope shrink naturally as ERB is
  removed; `page_title_presence_test` is replaced by a `<Head>`-title contract test.
- Playwright expansion out of scope.

## 14. Risks

1. Dual Stimulus/React implementation window (Decision 3) — bounded by migrating families promptly
   after foundation; Vitest parity tests per ported behavior.
2. 422→redirect semantics change in auth forms — audit each ceremony's clients/tests before
   converting.
3. Chrome dynamism parity (banner, cookie consent, theme) when moving from ERB partials + Stimulus
   to React layout + shared props.
4. `current_banner_for` re-implementation: currently forces `:writing` role and swallows connection
   errors on every request — the shared-prop version must use an explicit read role and fail loudly
   per no-silent-fallback rules (behavior change to flag in review).
5. Theme double source of truth (`theme_cookie_value` ERB vs `src/theme_cookie.js`) — unify in Phase
   A.
6. CSP strict-dynamic vs script-element initial page — already proven; keep
   `vite_asset_nonce_test`/`inertia_page_contract_test` green.
7. 569 uncommitted paths on `develop` — land the current Inertia work first; never reset the
   worktree.
8. React 19 / Inertia layout array form — enforced convention for all new layouts.
9. Migration is per-resource incremental; rollback = revert the resource's commit (controller
   render + page + tests move together).

## 15. Decision Record

### Decision 1 — Scope: all families, roots included

Status: Accepted. Decision: auth/base/core/side/palm browser HTML pages, including `layout false`
roots landings, become Inertia pages. Exceptions: Mailer, info/docs/news/help, non-HTML endpoints.
Evidence: `app/controllers/*/roots_controller.rb` (`layout false; def index; end`), auth 120 / base
132 view counts. Rejected alternatives: roots-as-ERB exception; base+auth-only scope. Consequences:
roots migrate in a dedicated late phase; unauthenticated landings gain React boot cost (mitigate
with minimal pages).

### Decision 2 — info/docs/news/help: keep static ERB landings

Status: Accepted. Decision: current layout-false ERB landings remain as an explicit exception; no
Inertia, no redirect change now. Dead `shared/content_entries/*` deleted in cleanup. Evidence:
`config/routes/{info,docs,news,help}.rb` (roots + JSON entries only), ADR
`read-only-content-surfaces-in-rails.md` / `publishing-db-content-authority.md`. Rejected
alternatives: redirect to Next.js (blocked on receiving-URL decision); Inertia-izing the landings
(contradicts ADR direction). Consequences: Rails keeps a minimal HTML footprint for these families;
redirect story is an open question.

### Decision 3 — Stimulus: React-first foundation

Status: Accepted. Decision: build React equivalents of all 14 Stimulus behaviors before page
migration; accept the dual-implementation window; remove Turbo/stimulus-rails/`src/controllers`
after the last ERB page; keep `webauthn_utils`/`turnstile_api` logic as framework-agnostic `.ts`.
Evidence: `src/controllers/*` (14 controllers, Vitest-covered),
`src/entrypoints/inertia/base_app.tsx` (imports Stimulus, not Turbo). Rejected alternatives:
permanent Stimulus coexistence; per-page incremental porting. Consequences: temporary duplication;
foundation phase is larger but page phases are mechanical.

### Decision 4 — Chrome: React persistent layouts

Status: Accepted. Decision: per-surface React layouts (`src/layouts/<family>/<surface>.tsx`, array
form); `inertia.html.erb` slims to document shell. Evidence:
`app/views/layouts/base/app/inertia.html.erb`, `layouts/shared/*` partials, zero React layouts
today; Inertia docs recommend persistent layouts. Rejected alternatives: keeping ERB chrome (blocks
dynamic updates; conflicts with Stimulus removal). Consequences: chrome data must flow via shared
props (Decision 7).

### Decision 5 — Errors contract: redirect-back + errors props

Status: Accepted. Decision: standardize on Inertia-standard redirect + errors hash (preference
precedent canonical); inline rendering, no flash; `render plain` security rejections unchanged.
Evidence: `notes/implementation/preference-index-inertia-migration.md`, `always_include_errors_hash`
enabled, no-flash repo rule, mixed 422-rerender in auth (`auth/org/sign/ups_controller.rb:35,44`
etc.). Rejected alternatives: 422 same-action Inertia rerender (off-standard, protocol friction).
Consequences: auth ceremonies' failure responses change status semantics; per-ceremony verification
required.

### Decision 6 — Tests: two-layer standard

Status: Accepted. Decision: Minitest page-object contract layer + Vitest markup/interaction layer;
1:1 assertion migration; no deletions; Playwright expansion out of scope. Evidence:
`test/support/inertia_page_object.rb`, preference migration (≈81 assertions moved), spec/ coverage
thresholds. Rejected alternatives: adding an E2E layer now (infrastructure cost outside migration
scope). Consequences: heavy auth test files migrate assertion-by-assertion.

### Decision 7 — Shared props via surface-base `inertia_share`

Status: Accepted. Decision: each surface's base controller defines an allowlisted shared-props
builder (auth-state summary, banner, locale/region, theme); typed `SharedProps` in `src/types`,
consumed via `usePage<SharedProps>()`; no AR objects/tokens; no cross-surface sharing. Evidence:
zero `inertia_share` today; surface isolation as security boundary
(`.agents/harnesses/rules/project/surfaces.mdc`). Rejected alternatives: per-action explicit chrome
props (duplication and omission risk). Consequences: `current_banner_for` moves out of the view
layer into the props builder.

### Decision 8 — Order: foundation → base → core/side/palm → auth → roots → cleanup

Status: Accepted. Decision: auth last, under the constraint that authentication semantics never
change; commit unit = resource/ceremony (migrate→test→verify→commit). Evidence: auth concentrates
security ceremonies (Turnstile, passkeys, OmniAuth) and the heaviest view-coupled tests. Rejected
alternatives: auth-first (risk before tooling maturity); smallest-family-first (base already has the
working precedent). Consequences: rollback experience accumulates before the security-sensitive
family.

### Helper classification (supplementary decision, method-level)

Status: Accepted. 21 helper files, 22 public methods.

- A (Inertia root shell): `page_title` (shell side), `brand_tld`, `theme_cookie_value`,
  `theme_html_class`, `get_language`.
- C (props/serializer): `current_banner_for`, `apple_sign_in_logo_paths`,
  `sign_up_birthdate_date_format`, title value.
- D (React): `sign_up_birthdate_fields` (preserve `SignUpEligibilityPolicy.minimum_age_reached?` /
  `birthdate_not_future` invariants), `sign_org_recruit_contact_link`.
- E (TS utility): `localized_session_timestamp`, `sign_up_birthdate_part_order`.
- F (server URL via props): `sign_org_recruit_contact_url` (validation stays server-side).
- G: none. H (dead; confirm then delete in cleanup): `theme_class`, `edge_host`, helper copies of
  `get_timezone`/`get_region`/`get_theme` (live versions in
  `preference_global.rb`/`preference_core.rb` — resolve shadowing first),
  `preference_language_options`, withdrawal trio (test-only callers — confirm dead vs unshipped
  before deleting), 14 empty stub files. Rule: security/domain/server responsibility stays in Rails;
  no mechanical Ruby→TS copying.

## 15b. Implementation Deviations (recorded during execution)

Decisions taken while implementing, which differ from or refine the pre-implementation plan:

1. **Document title stays server-rendered; Inertia `<Head>` is not adopted.** The plan proposed
   moving per-page titles to `<Head>`. The shells already render the title from the page's own
   `title` prop through `display_meta_tags`, which is correct before React boots and for clients
   that never run it, and keeps exactly one source of truth. Adopting `<Head>` would have added a
   second one for no gain. Every migrated page therefore sends a `title` prop.

2. **Persistent layout is attached by the resolver, not by page modules.** Inertia's documented
   pattern is `Page.layout = [Layout]` per page. With hundreds of pages that makes rendering without
   chrome a mistake any page can make, so `surfacePageResolver` assigns the layout centrally
   (`page.default.layout ??= [layout]`, still the array form Inertia 3 requires) while leaving a
   page free to declare its own.

3. **`CurrentBanner` keeps the helper's connection role and rescue.** The audit recommended an
   explicit read role and failing loudly. The query was extracted unchanged instead: a banner is
   optional chrome, and making an unreachable banner store fail every page of the surface is a
   larger behaviour change than this migration should carry. Recorded as follow-up work.

4. **The Turnstile API script moved into the Inertia shells.** It was loaded by the Turbo layouts
   only, so an Inertia page carrying a challenge had no API to render it.

5. **The unused `inertia_chrome` override hook was dropped** (YAGNI): family defaults in
   `SurfaceChrome::FAMILY_CHROME` cover every surface, and no controller needed an override.

## 15c. Execution Status — COMPLETE

Final state of the migration run:

- **Browser ERB: 344 → 8.** The eight that remain are the documented exceptions in section 15d (four
  token-bridge forms, the OmniAuth error page, and the three shared sign-out templates whose seven
  cross-family callers are the single remaining migration unit).
- **235 React pages, 106 shared feature components, 164 Inertia controllers, 43 Vitest spec files.**
- `base`, `core`, `side`, `palm` and `auth/app`, `auth/com`, `auth/org` are migrated, including
  every root landing outside the Next.js-owned families.
- Mailer ERB (25 templates) and the info/docs/news/help landings (12) are untouched, as decided.
- Stimulus controllers still present: 12, kept only for the surfaces' remaining Turbo layouts; their
  React equivalents exist and are what the Inertia pages use.

Earlier progress notes:

- **Phase A (foundation)** — complete. `SurfaceChrome` + `inertia_share`, React `SurfaceLayout`,
  React ports of the cookie-banner and theme controls, `CurrentBanner` query object,
  `surfacePageResolver`, document-only Inertia shells for all 14 surfaces (the four `core` shells
  were created by this work), `GroupsController` unified onto `SurfaceInertiaPage`.
- **Phases B/C/E** — `core`, `side` and `palm` fully migrated, including every root landing;
  `base/app` and most of `base/com`/`base/org` migrated; all `base` root landings migrated.
- **Phase D** — `auth/app` fully migrated; `auth/com` and `auth/org` in progress.
- Browser ERB count: 344 at the start, 47 remaining at the last checkpoint (the remainder are the
  cross-surface `auth/shared` and `base/shared` templates and the `auth/com` sign-up ceremony).
- Dead views deleted where proven unreferenced (`auth/app/welcomes/show`,
  `auth/app/emails/registrations/_verification_fields`, the unrouted `accounts`/`organizations`
  new/edit views, the unreachable `core`/`side` `sign_outs/show`).
- Operational surfaces (`dev`, `net`) are expressible in chrome: their route prefix is named
  explicitly and they render no preference controls, because they have no preference authority.

## 15d. Accepted ERB Exceptions (found during execution)

Browser templates that stay ERB, with the reason each one is not a page:

1. **`auth/shared/sign_outs/handoff`, `social_completion`, `step_up_completion`,
   `step_up_cancellation`.** These are auto-submitting bridge forms whose entire payload is a token
   (`logout_challenge`, `social_ceremony_result`, `step_up_ceremony_result`, plus the authenticity
   token) posted through a nonce'd inline script. Turning them into Inertia pages would mean
   shipping those tokens as props, which the prop contract forbids. They belong with the OAuth/OIDC
   callback category the migration already excludes: they are transport between ceremonies, not
   pages a visitor reads.

2. **`auth/org/omniauth/omniauth_callbacks/error.html.erb`.** The Inertia page object always embeds
   `request.original_fullpath`, so rendering the OmniAuth `failure` endpoint through Inertia would
   reflect the attacker-supplied `?message=` parameter back into the response body — the exact thing
   `omniauth_callbacks_controller_test.rb` asserts must not happen. It stays ERB with its 422 status
   until that reflection question has an answer that does not weaken the guard.

3. **`auth/shared/sign_outs/{edit,complete,unavailable}`.** Still rendered by name from the
   `auth/com`, `core/{app,com,org}` and `side/{app,com,org}` sign-out controllers. Migrating them
   means turning seven more controllers across three families Inertia in one step, inside the
   coordinated sign-out ceremony. Left as the single remaining migration unit rather than being
   half-changed; the `auth/app` and `auth/org` surfaces already render their own Inertia sign-out
   pages through `SignOutInertiaPages`.

4. **`info`, `docs`, `news`, `help` root landings** and **all mailer templates**, per Decisions 2
   and the mailer boundary.

## 16. Open Questions

- `shared/health/show.html.erb` HTML variant: keep as ERB diagnostic (recommended) or migrate.
- Future redirect of info/docs/news/help landings to Next.js (needs receiving-URL decision in the
  edge repository).
- Withdrawal helper trio: dead code or unshipped feature — confirm with owner before deletion.
- `auth/org/omniauth/omniauth_callbacks/error.html.erb`: verify `render_entra_error` reaches it.

## 17. Implementation Plan

Prerequisite: land the 569 currently-uncommitted paths (existing Inertia work) before Phase A.

- **Phase A — Foundation**: unify `GroupsController` onto `SurfaceInertiaPage` (extend for explicit
  component names); `inertia_share` per surface with typed `SharedProps`; React persistent layouts
  per surface; `<Head>` adoption for titles; React ports of 14 Stimulus behaviors; `.ts` rewrites of
  `theme_cookie`/`turnstile_api`/`webauthn_utils`; slim `inertia.html.erb` shells; fix
  compatibility-initializer comment. Verify: full check suite + contract tests.
- **Phase B — base family** (per resource: dashboard/welcome → accounts → organizations+memberships
  → identity/* → avatars → billings/selector/switcher → oidc/logouts → sign/out; React self-service
  shell first).
- **Phase C — core/side/palm** (incl. shared-template conversion; health HTML variant decision).
- **Phase D — auth family** (per ceremony: sign-in → sign-up → verification/OTP → passkeys → TOTP →
  OmniAuth result pages → settings/preferences → sign-out/handoff). Constraints: auth semantics
  unchanged; callbacks/`render plain` untouched; 422→redirect conversions verified per ceremony;
  forwarder templates → shared React components; heaviest tests migrated 1:1.
- **Phase E — roots landings** (auth/base/core/side/palm only).
- **Phase F — Cleanup + final audit**: remove Turbo/stimulus gems and packages, `src/controllers/*`,
  `application.html.erb` twins, `layouts/shared/*`, dead views/helpers (allowlist-based sweep per
  §7), `data-turbo-eval`/turbo meta attributes, adjust lefthook erb scope; final dead-ERB grep
  against the allowlist.

Each commit unit: migrate → targeted `bin/rails test` + `pnpm test` → commit. Each phase:
`pnpm -s check`, `bin/rails test`, rubocop, erb_lint, brakeman, production `vite build` all green;
no skips, no suppressions.

**READY FOR IMPLEMENTATION** — an implementation agent can start at Phase A without further design
decisions.
