# Signed-In Preference Behavior Review (two.md WU-9 Closure)

Date: 2026-11-03

Status: Backlog. To be resumed in a separate conversation after the OP-mediated step-up
implementation (`specs/op-mediated-step-up/`) is finished by Codex. Nothing in this file has been
investigated at runtime; it is a starting point, not a finding.

## Why this is next

In `two.md`, WU-9 (the new Preference model for app/org and its Visa sign-in/sign-out connection) is
the next unit after the current work. Its order and the following units are in `two.md` §1.1: WU-9,
then WU-X1, WU-X2, WU-E. The signed-out Preference path was cleaned up earlier (query count and
N+1). The signed-in path has not been looked at the same way.

## Current WU-9 state (from evidence records, not reverified)

- `evidence/2026-11-01-wu9-closure-result-R6T2.md`: WU-9 is not complete.
- `evidence/2026-11-01-wu9-visa-post-continuation-Q7M2.md` and
  `evidence/2026-11-02-wu9-visa-post-continuation-recheck-V3M8.md`: the Visa GET-versus-POST
  continuation (`two.md` §12.5) was implemented afterwards and checked by focused runs only; the
  complete continuation matrix is not verified.
- `evidence/2026-11-01-wu9-final-suite-baseline-Q4M8.md`: the last full run had 16,659 runs, 154
  failures and 4,883 errors; 4,707 failing identifiers are outside
  `plans/2026-10-28-baseline-failing-tests.md`. Causes were not attributed.
- Open for closure: the WU-9 acceptance matrix across APP, ORG and COM (AC-20b to AC-37, AC-49,
  AC-52 per `two.md` §3.12), the reset and sign-out failure cases, and the final baseline
  comparison.

## Known problems

1. Test database fixture residue. Many tests stop at fixture setup with a foreign-key violation in
   `test_app_zenith_db` (`enterprise_units` / `persona_memberships` referencing a missing
   `enterprises.id = 519260501`), and leftover non-fixture `clients` rows recur after single-process
   runs of non-transactional tests. The owner earlier decided not to handle the general `rails test`
   residue problem, but WU-9 closure needs a full run. A scoped cleanup authorization (as given for
   the step-up work in `zero.md`, 2026-11-03 17:45 and 18:30) or a fix of the residue source must be
   decided first. Note the step-up cleanup once deleted and reinserted the `zero` fixture Client
   (explicit `id: 0`); an inventory must use each fixture's explicit `id`.
2. Preference contract tests reported as failing or outdated in the closure run (reset cookie,
   audit, locale, timezone, token, option); unverified while fixture setup fails.
3. Resolved, kept for history: the WU-X1 collision recorded in
   `evidence/2026-10-31-wux1-org-settings-collision-T6C4.md` no longer exists. The Auth ORG
   `ConfigurationsController` was removed in commit `efdcd80d3`, and
   `test/integration/routes/auth_sign_ceremony_route_contract_test.rb` and
   `test/config/org_settings_routes_test.rb` assert that `/configuration` is not routable (checked
   by reading on 2026-11-04, tests not run). The remaining Auth `/settings` pages are now governed
   by the step-up contract's Auth and Base split (O-11): most of them move to Base.

## Signed-in behavior to examine (design in `two.md` §4.5 to §4.8)

| Area                           | Expected by design                                                                                                                                                                          | What to check                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Display read on non-Base hosts | Verified JWT values only; zero DB access, signed in or not                                                                                                                                  | Any query here is a defect                                                    |
| Display read on Base           | `Actor.preferences` = JWT display values + Base-owned DB items (consent, region, Web Push); consent and Web Push only with an active setting row and a matching `__Host-preference_binding` | Query count per page, N+1 on child tables, account row vs anonymous row reads |
| Settings form initial values   | Account explicit, then anonymous DB, then default; save sends only changed items                                                                                                            | No bulk POST of initial values                                                |
| Signed-in save                 | Commit account (Z) first, release its lock, then lock and reload the setting row (S) and recheck `jti`; failure between them is 503, not success                                            | Lock order, partial-failure response                                          |
| Visa sign-in                   | Copy only explicitly saved account items to the anonymous row; never region itself, consent or Web Push; account rows unchanged                                                             | No account writes, explicit-only copy                                         |
| Visa sign-out                  | Copy display, consent, Web Push and binding record from the old anonymous row to a new one in one transaction; sign-out completes even if Preference cleanup fails                          | Atomicity, no false success                                                   |
| Reset                          | Retire old anonymous row and account settings, reissue the three shared cookies, discard the old binding cookie                                                                             | Partial-failure reporting                                                     |
| Failure table                  | `two.md` §4.8 (DB read failure, signing failure, cookie delivery failure)                                                                                                                   | Public responses match                                                        |

## Suggested start

1. Observe first, as done for the signed-out path: in development, signed in, exercise Base page
   display, a non-Base page display, a settings save, sign-in, sign-out and reset, and read the
   development log (query count, tables read, cookies issued). Record observations in `evidence/`.
2. Compare the observations with the table above and list discrepancies before changing code.
3. Decide the test database cleanup scope (problem 1) before any WU-9 closure test run.

## Not verified

- Every statement about current behavior above comes from `two.md` and evidence records; no code was
  read or run for this note.
- Whether WU-A1 to WU-A14 are individually complete.

## Observation 2026-11-03: theme saved on Base is not applied on www-jp

Reported by the owner: signed in, set theme to light at
`https://www.umaxica.app/preference/theme/edit?ri=us`; `https://www-jp.umaxica.app/` did not show
it.

Source reading (not runtime-verified), all suggesting it should work:

- The save (`Base::App::Preference::ThemesController#update`) completed with 302 in the development
  log; it goes through `write_app_org_preference!` and `emit_anonymous_realm_token!`
  (`app/controllers/concerns/preference_write_boundary.rb`).
- The three cookies `__Secure-preference`, `language`, `__Secure-experience` are issued with
  `Domain=.umaxica.app` (`anonymous_com_cookie_domain` in
  `app/controllers/concerns/preference_access_token_issuer.rb`).
- The JWT realm is derived from the registrable domain
  (`SecurityJwtPreferenceTokenCodec.configured_anonymous_realm_for_host`), so www-jp resolves to
  `app` too.
- `Warp::App::RootsController` renders `data-theme` from `Actor.preferences`, which comes from the
  verified JWT (`ActorSupport#resolved_current_preference`); it ran with 0 queries.

Suspicious: `log/development.access.jsonl` has Warp `/api/v0/preferences/theme` and `/cookie`
returning 302 to their own URL. The access log has no timestamps, so it is not known whether this
happened during the reported attempt.

Next check (in the browser on www-jp): presence and Domain of `__Secure-preference` and
`__Secure-experience`; the `theme` value in `__Secure-experience`; `<html data-theme>`; whether
`/api/v0/preferences/theme` returns 302. `data-theme=light` with a dark page points to the front
end; `system` points to JWT reading on the server; missing cookies point to issuance.

## Owner direction 2026-11-03: a general notification settings page

Requirement background: one.md D-20/D-23/D-24 add a Web Push item (`enabled`/`disabled`, default
`disabled`) to app/com/org Preference without a delivery mechanism. Current state (source reading):
`*_preference_web_push(_option)` models and a JSON API `GET`/`PATCH /api/v0/preferences/web_push`
exist on all three surfaces; no HTML settings screen exists. The API routes use
`get :web_push, to: "web_pushes#show"` (`config/routes/base.rb:185`, `:359`, `:627`), which does not
follow the resourceful routing policy.

The owner wants a general notification page, not a page named after Web Push. Proposed shape, to be
confirmed in the next conversation:

- Screen: `resource :notification, only: %i(edit update)` under each surface's `preference`
  namespace (`/preference/notification/edit`), app/com/org.
- Web Push is one item on that page; the stored item keeps its name (`web_push`), since it is the
  specific channel. Future channels are added as further items on the same page.
- Existing `preference/emails` is the token-authenticated promotional-email unsubscribe screen (bare
  endpoint, no session); decide whether the notification page links to it or stays separate.
- Decide whether signed-out visitors can save (the current design stores Web Push on the anonymous
  setting row with `__Host-preference_binding`), and whether the JSON API routes are moved to
  `resource :web_push, only: %i(show update)` in the same change.
- Record the screen in `two.md` or a spec before implementation; it is not in the current design.

### Owner decisions on the notification page (2026-11-03)

1. `preference/emails` stays separate from the notification page. The owner considers it likely
   broken and in need of redesign, including whether it belongs on Auth instead of Base. That is a
   separate backlog item; not investigated yet.
2. Write design: use a form object for the notification save, with an explicit switch between the
   signed-in and the signed-out write paths, instead of one controller branching on the session. The
   exact writes of each path (account row, anonymous setting row, binding) are to be designed before
   implementation; `two.md` §4.5 and §4.7 are the current reference (Web Push is stored on the Base
   setting row with the browser binding and is not synchronized to the account).
3. Move the Web Push JSON API routes to the resourceful form
   (`resource :web_push, only: %i(show update)`) in the same change as the notification page,
   updating front-end callers and tests.

### Notification page mock-up state (2026-11-03)

Built by Claude Code at the owner's request so the page can be reviewed; it stores nothing. Checked
in development only (each surface renders 200; an empty PATCH returns 303 to edit). No tests were
added. RuboCop and oxfmt pass; the repository-wide TypeScript check fails only on the pre-existing
unrelated `gait/pages/auth/org/org_auth_screens.test.tsx:342`.

- Routes: `resource :notification, only: %i(edit update)` in the app, com and org `preference`
  namespaces (`config/routes/base.rb`). This also maps PUT, which
  `adr/api-route-vocabulary-consolidation.md` avoids for the JSON API; decide the route form for
  both this page and the Web Push API in the real implementation.
- Index link: `notification: :notification_settings` in
  `app/controllers/concerns/base_preference_index_page.rb`, listed after cookie settings.
- Controllers: `app/controllers/base/{app,com,org}/preference/notifications_controller.rb`, each
  including `app/controllers/concerns/base_preference_notification_screen.rb`.
- Scaffold-shaped flow: `edit` builds `PreferenceNotificationForm.new` and renders Inertia
  `base/<surface>/preference/notifications/edit`; `update` builds the form from
  `params.fetch("preference_notification", {}).permit` (nothing permitted yet), redirects 303 to
  edit on `save`, and re-renders with 422 and errors otherwise.
- Form object: `app/forms/preference_notification_form.rb` (`ApplicationForm`); no attributes,
  `save` only runs `valid?`.
- Screen: `src/features/preferences/PreferenceNotification.tsx`, re-exported by
  `src/pages/base/{app,com,org}/preference/notifications/edit.tsx`. It shows the placeholder text, a
  Web Push select (enabled/disabled, initial value `disabled` fixed on the server per D-24), and the
  update button, which sends an empty Inertia PATCH. The Web Push value is kept in the page only and
  is not submitted.
- Locale keys: `base.{app,com,org}.preferences.notification_settings` and
  `notification.{title,description,placeholder,web_push.{label,enabled,disabled}}` in
  `config/locales/{en,ja}.yml`.

Remaining for the real implementation: add `web_push` to the form object and `permit`, submit it
from the screen, read the stored value instead of the fixed default, design the signed-in and
signed-out write paths inside the form object, decide the route form, add public-boundary tests, and
remove the mock wording.
