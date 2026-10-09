# Preference Domain Audit — Final Report (2026-07-02)

## Scope

Full audit of the Umaxica Preference domain: behavior contract, DB/cookie/request-state authority
order, anonymous-to-signed-in sync, logout downgrade, cookie consent, security negative cases, and
maintainability. JWT implementation itself was explicitly out of scope. This report covers both the
in-flight audit found already in the working tree at session start (C1/H1/M1, already fixed and
documented in `research/2026-07-02-preference-audit.md`) and the follow-up work completed in this
pass (regression tests for previously untested contract gaps, plus M2/L1/GET-edit fixes).

## Findings summary

| ID                                  | Severity      | Status                   | Summary                                                                                                                                                                                                                      |
| ----------------------------------- | ------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1                                  | Critical      | Fixed (prior pass)       | `show_banner?` was hardcoded to `false`; cookie consent banner never rendered.                                                                                                                                               |
| H1                                  | High          | Fixed (prior pass)       | `base/org/edge/v0/cookies_controller` was missing `skip_before_action :transparent_refresh_access_token`, unlike app/com.                                                                                                    |
| M1                                  | Medium        | Fixed (prior pass)       | `OrgPreferenceCookie#set_defaults` was missing the `functional` default present on app/com.                                                                                                                                  |
| M2                                  | Medium        | Fixed (this pass)        | `app_preferences.status_id` column default (`2`) diverged from the model's Ruby-level default (`0`); `persist_self_replacement` used `update!` on App vs. `update_column` on Com/Org.                                        |
| GET-edit                            | High          | Fixed (this pass)        | `*_preferences_edit` actions (region/language/timezone/theme) created a missing child row as a side effect of `GET`, violating the "no GET mutation" contract rule.                                                          |
| L1                                  | Low           | Fixed (this pass)        | Dead `has_one :user_preference_colortheme` alias on `ClientPreference`, left over from the `colortheme` → `theme` rename.                                                                                                    |
| L2                                  | Low           | Deferred to backlog      | Denormalized columns and normalized child tables coexist on Client/Operator/VisitorPreference. Already tracked by `plans/backlog/legacy-preference-models-retirement-plan.md`.                                               |
| Logout downgrade                    | Decision      | Confirmed as keep-values | Logout intentionally keeps guest-safe display preferences (language/timezone/theme/cookie-banner suppression); only auth/session transport cookies are cleared. Documented as the accepted contract, not an unresolved TODO. |
| Corrupt/cross-surface refresh token | Verified safe | No code change needed    | A presented-but-invalid or cross-surface refresh token fails closed with `401` and clears the stale cookie; it never resolves to or mutates an unrelated preference row.                                                     |

## Changed files

- `app/controllers/concerns/preference_base.rb` — added `load_or_build_preference_child` (GET-safe,
  non-persisting child reader).
- `app/controllers/concerns/preference_core.rb` — added `load_or_refresh_preference_child_for_edit`;
  switched all four `*_preferences_edit` actions (region/language/timezone/theme) to it.
- `app/models/app_preference.rb` — `persist_self_replacement` now uses `update_column`, matching
  Com/Org.
- `app/models/client_preference.rb` — removed the dead `user_preference_colortheme` alias.
- `db/app_settings_migrate/20260702000000_change_app_preferences_status_id_default_to_nothing.rb` —
  new reversible migration (`change_column_default :app_preferences, :status_id, from: 2, to: 0`).
- `docs/architecture/preference-behavior-contract.md` — updated State Transitions (logout,
  logged-out revisit), Security Negative Cases (GET mutation, cookie tampering), inventory test
  list, and Maintainability Rules (persist_self_replacement / status_id default parity).
- `research/2026-07-02-preference-audit.md` — appended an English "Update" section recording the
  M2/L1/ GET-edit resolution and the additional regression tests.

## Regression tests added (this pass)

- `test/integration/preference_corrupt_cookie_test.rb` — garbage/invalid refresh cookie and access
  JWT fail closed without raising and without corrupting an unrelated existing preference; an absent
  cookie still bootstraps normally.
- `test/integration/preference_signin_conflict_test.rb` — the verified preference access token wins
  over a conflicting public display cookie, for both theme and cookie-consent reads.
- `test/integration/preference_logout_downgrade_test.rb` — logout keeps guest-safe display cookies
  and the preference record's stored values; only the session cookie is cleared.
- `test/integration/preference_concurrent_sync_test.rb` — jti/public_id uniqueness and
  single-canonical-row invariants hold across a burst of sequential writes (a stand-in for
  interleaved concurrent requests, since Minitest cannot exercise true thread concurrency).
- `test/integration/preference_read_symmetry_test.rb` — anonymous and signed-in theme reads agree on
  the value written, including the resource-mirror's denormalized `theme` column.
- Extended `test/integration/preference_security_test.rb` with two cross-surface inertness cases (an
  app-issued refresh cookie is inert on com/org hosts).
- Rewrote `test/integration/preference_get_edit_current_behavior_test.rb` to assert the new
  no-GET-mutation contract instead of documenting the old side effect.

## Verification performed

- All new/updated test files: green.
- `test/controllers/concerns/preference/`, `test/integration/preference_security_test.rb`,
  `test/integration/acme_preference_test.rb`, `test/integration/preference_booster_test.rb`,
  `test/models/{app,com,org}_preference_test.rb`,
  `test/models/{app,com,org}_preference_cookie_test.rb`: re-run after the M2/GET-edit changes. Same
  5 pre-existing failures reproduce unchanged (`adoption_test.rb` ×2, `jwt_and_color_theme_test.rb`
  ×2, `no_implicit_callbacks_test.rb` ×1) — confirmed pre-existing on `develop`, unrelated to this
  pass.
- Migration round-trip: ran `bin/rails db:migrate:reset` and
  `RAILS_ENV=test bin/rails db:migrate:reset` (this app's required workflow for multi-DB schema
  changes per `docs/operations/db-workflow.md`, since `bin/rails db:verify_no_schema_drift` is not
  wired up as a rake task in this repo despite being referenced in that doc) — confirmed
  `app_preferences.status_id` default is `0` post-migration. Fixtures hardcode `status_id: 2`
  explicitly and are unaffected by the column default change.

## Remaining risks / open items

- `docs/architecture/preference.md`'s "Should logout clear the local copy?" open question is now
  answered (keep-values); the doc itself was not edited in this pass — a follow-up should close that
  open question there too, or point it at the contract doc.
- L2 (denormalized-column retirement) remains deferred to
  `plans/backlog/legacy-preference-models-retirement-plan.md`; not touched in this pass.
- The 5 pre-existing test failures (`adoption_test.rb`, `jwt_and_color_theme_test.rb`,
  `no_implicit_callbacks_test.rb`) were confirmed unrelated to this audit's changes but were not
  triaged or fixed — they were already present on `develop` before this session started and are
  independent of the preference-domain work here.
- `docs/architecture/preference-behavior-contract.md`'s `db:verify_no_schema_drift` reference does
  not correspond to an actual rake task in this repo; worth confirming whether that's aspirational
  documentation or a missing task definition.

## Next things to look at

1. Decide whether to formally close the `preference.md` open question or fold that document into the
   contract doc to avoid two sources of truth.
2. Triage the 5 pre-existing test failures as separate, unrelated work.
3. Revisit L2 (denormalized vs. normalized preference columns) via the existing backlog plan when
   capacity allows.
