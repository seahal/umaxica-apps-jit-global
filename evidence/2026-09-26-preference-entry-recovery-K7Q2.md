# Preference Credential Entry Recovery

Commit: e423890e7357e1fa7975eac45aeacdb416b3bce9. The worktree had unrelated uncommitted changes, and
it also had this change uncommitted.

## Reproduction (before the change)

The new `test/integration/preference_entry_recovery_test.rb` ran against the unchanged code. It
plants a refresh cookie whose `public_id` has no record. On `app`, `com`, and `org`, the Auth
sign-in entry returned `401` on GET and HEAD. The Base start POST also returned `401`. The direct
entry bridge and the `org` sign-up guide returned `401` as well. Result: 14 failures.

## After the change

- `bin/rails test test/integration/preference_entry_recovery_test.rb`: 22 runs, 0 failures.
- `bin/rails test test/integration/preference_*_test.rb test/controllers/auth
  test/controllers/base/app/roots_controller_test.rb test/controllers/base/com
  test/controllers/base/org test/controllers/concerns test/security`: 2447 runs, 0 failures,
  0 errors, 1 skip (pre-existing).
- RuboCop on the touched files: no new offenses. Three pre-existing `Style/ImplicitRuntimeError`
  offenses remain in the Base roots controllers.

## Not performed

- The full `bin/rails test` suite, Vitest, and Playwright.
- Real-browser checks in Chromium, Firefox, and WebKit.
- Database or Valkey outage injection.
- Inspection of the production incident's environment and logs.

## Observation outside scope (resolved)

An Auth sign-in POST with a wrong `authenticity_token` and no explicit `Sec-Fetch-Site` header
returned `303` in an integration test. A probe of `verify_request_for_forgery_protection` showed
`sec_fetch_site_value == "same-origin"`. `test/support/fetch_metadata_defaults.rb` injects that
header into every integration request, and Rails 8.2 `header_or_legacy_token` accepts
`same-origin` without checking the token. The `303` is therefore test-harness behavior, not a gap
in the application's CSRF defenses. With an explicit `Sec-Fetch-Site: cross-site` header, the same
request is refused.
