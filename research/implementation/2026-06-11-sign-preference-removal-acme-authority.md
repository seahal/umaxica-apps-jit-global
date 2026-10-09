# Sign (`id`) preference removal — acme/www is now the sole preference authority

Date: 2026-06-11

## What changed

Removed the entire sign (`id.umaxica.{app,com,org}`) `/preference` implementation so those URLs now
return 404, and consolidated preference (including promotional email unsubscribe) onto acme
(`www.umaxica.{app,com,org}`). This realizes `adr/identity-authority-boundary.md` (Accepted
2026-06-02), which assigns the Preference Authority exclusively to acme/www and prohibits sign/id
from owning preference writes.

Before this change the migration was half-done: in production (`request.ssl?`) the sign
`PreferencesBaseController` short-circuited its acme redirect and still rendered/handled preferences
directly; only on localhost did it redirect. Two live implementations existed.

The user explicitly approved the breaking change, including 404 (no redirect shim) and migrating the
promotional email unsubscribe endpoints to acme.

## Removed

- Sign preference routes in `config/routes/sign.rb` (app/com/org `# Preferences` blocks).
- `app/controllers/sign/{app,com,org}/preferences_controller.rb` and the entire
  `app/controllers/sign/{app,com,org}/preference/` trees (region…reset_attempt, emails, redirects).
- `app/views/sign/{app,com,org}/preference(s)/`, `app/helpers/sign/*/preferences_helper.rb`.
- Concerns `sign_preference_authority_redirect.rb` and
  `sign_promotional_email_unsubscribe_actions.rb`.
- Sign preference controller/integration tests (redirect-only ones deleted; behavior ones migrated).

## Kept deliberately (NOT sign preference)

- `Sign::{App,Com,Org}::PreferencesBaseController` — still the parent of the **sign-owned web/v0
  JSON cookie/theme API** (`sign/*/web/v0/{cookies,themes}_controller`). These are a separate
  surface, not the `/preference` HTML feature, and were out of scope. Restored from git after an
  initial over-broad delete.
- `Sign::RedirectOnlyController` (used by ~20 non-preference controllers).
- All `*_preference*` models and model concerns (shared data layer used by acme too).
- `app/views/sign/shared/preference/selectable.html.erb` — still rendered by
  `PreferenceSignScreenActions#edit_selectable_preference_screen` (now acme-only path).

## Added (acme parity)

- `resources :emails` + `post "emails/:id"` under each acme preference namespace in
  `config/routes/acme.rb`.
- `app/controllers/acme/{app,com,org}/preference/emails_controller.rb`
  (`< Acme::*::BareController`).
- Surface-neutral concern `promotional_email_unsubscribe_actions.rb` (generalized from the deleted
  sign concern; only the per-controller `redirect_after_unsubscribe_path` is surface-specific).
- `app/views/acme/shared/preference/_email_unsubscribe.html.erb` + per-surface
  `acme/*/preference/emails/edit.html.erb`.

## Caller repointing

- Mailer `app/mailers/concerns/promotional_email_unsubscribe_headers.rb`: `List-Unsubscribe` headers
  now use `acme_*_preference_email_url` on the acme hosts.
- Sign layout footers (`layouts/sign/*/application.html.erb`) preference link →
  `acme_*_preference_url`.
- `layouts/shared/_footer_cookie_controls.html.erb`: cookie banner settings link now always targets
  `edit_acme_#{scope}_preference_cookie_url` (was derived from the current controller's surface
  prefix, which broke on sign pages once sign routes were removed). Uses `_url` for cross-host.

## Behavior fixes surfaced by the migration (shared concerns)

- `PreferenceGlobal#redirect_to_context_query` now builds the canonicalization redirect from
  `request.path` instead of `url_for(controller:, action:)`. Acme routes every screen through one
  `screens` controller, so the old approach collapsed to the first screen route (region) and bounced
  users off their current screen. The `request.path` approach matches the existing
  `build_ri_redirect_url` pattern and is surface-agnostic.
- `PreferenceSignScreenActions#destroy_reset_preference_screen` now renders
  `acme/shared/preference/resets` (not `:edit`) on the invalid/unconfirmed path; acme has no
  per-surface `resets/edit` template, so `render :edit` raised MissingTemplate.
- Removed a now-unreachable sign-template fallback in
  `AcmePreferenceScreenDispatch#preference_screen_template` (the dispatch concern is acme-only now).

## Behavior differences to be aware of (acme rendering)

- Acme language options render abbreviated codes ("Ja"/"En") where the old sign views showed native
  names ("日本語"/"English"). Acme theme "Dark" is `option value="2"` (numeric), not `"dark"`. The
  migrated `test/integration/acme_preference_test.rb` asserts acme's actual rendering. If native
  language names are desired UX, that is a separate acme view enhancement.

## Follow-ups / cleanup candidates (not done here)

- `AcmePreferenceViewRouteAliases` (aliases `sign_*_preference*` → `acme_*` for acme controllers) is
  now effectively unused since acme views call `acme_*` directly; safe to remove later.
- `PreferenceSignScreenActions` is misnamed (acme-only now) and renders the sign-namespaced
  `sign/shared/preference/selectable` template while an unused `acme/shared/preference/selectable`
  exists. Consider renaming the concern and consolidating the selectable template.
- `adr/identity-authority-boundary.md` still lists "acme preference authority" as a required
  follow-up ADR; this removal is a concrete step toward it.
  `plans/identity-authority-inversion- implementation.md` tracked the gap "Acme preference
  routes/controllers/dispatch still expose old acme preference-authority behavior" — sign-side is
  now gone.

## Verification

`bin/rails routes -g preference` shows only acme routes (no sign). 247 runs / 0 failures across the
migrated + adjacent suites: `acme_preference_test`, `preference_security_test`,
`preference_global_param_context_test`, `preference_booster_test`, acme email controllers, acme
slice, sign `preferences_base_controller_test`, sign web/v0 cookie/theme, mailer unsubscribe header
tests, and sign roots/dashboards (footer rendering). Full-suite run still pending in CI (sandbox
Vite asset builds are flaky under load here).
