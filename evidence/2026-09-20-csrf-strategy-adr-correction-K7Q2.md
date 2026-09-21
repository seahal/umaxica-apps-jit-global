# CSRF verification strategy: ADR correction and controller sweep

Date: 2026-09-20

## What was checked

Whether every controller root declares `protect_from_forgery using: :header_or_legacy_token`, and
whether the surrounding documentation describes the Rails 8.2 strategy accurately.

## Observed

All 59 classes inheriting `ActionController::Base` directly declare
`protect_from_forgery using: :header_or_legacy_token`. Two deliberate exceptions exist:

- `app/controllers/base/app/oidc/logouts_controller.rb` uses `:header_only` for `create` only, gated
  on `params[:logout_challenge].present?` with exact `trusted_origins`, paired with
  `verify_coordinated_sign_out_post!`. This is stricter than the repository baseline, not weaker.
  It carried no comment; a security-exception comment was added naming the three bounding axes and
  the paired `before_action`.
- `app/controllers/concerns/csp_violation_report.rb` calls `skip_forgery_protection(only: :create)`
  for browser-generated CSP telemetry. Already documented in place; unchanged.

`app/controllers/application_controller.rb` declared the strategy without `with: :exception`, unlike
every surface root. `with: :exception` was added so the failure mode is explicit rather than an
implicit consequence of `config.load_defaults`.

## Documentation defect corrected

`adr/csrf-protection-disabled-in-test-environment.md` argued that a bare test request verifies
successfully under the application's strategy. Read against the vendored Rails revision
`6610cb45b39b`, `actionpack/lib/action_controller/metal/request_forgery_protection.rb`:

- `verified_via_header_only?` returns true for a nil `Sec-Fetch-Site` over a non-SSL connection.
  This is the `:header_only` path.
- `verified_with_legacy_token?` (the `:header_or_legacy_token` path the application actually uses)
  instruments `csrf_token_fallback` and returns `any_authenticity_token_valid?` for a missing or
  `none` header, so a bare test request is rejected.

The ADR's second argument was therefore inverted. Corrected in place with a dated Status amendment;
the decision (off by default in test, permanent, per-test opt-in explicitly allowed) is unchanged
and now rests on the Rails-default and cost/duplication arguments. The same misapplication in
`docs/security/authentication-boundary-audit.md` was corrected, and the comment on
`config/environments/test.rb` was rewritten to match.

## Verification run

- `bin/rails test test/controllers/protocol_controller_csrf_boundary_test.rb
  test/integration/social_completion_cross_host_csrf_test.rb
  test/integration/csrf_notification_emission_test.rb test/integration/preference_web_csrf_test.rb`
  -> 23 runs, 109 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/auth/oidc_logouts_controller_test.rb
  test/controllers/auth/token_csrf_test.rb test/integration/csrf_notification_emission_test.rb
  test/controllers/base/com/oidc/logouts_controller_test.rb`
  -> 14 runs, 59 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/auth_redirect_booster_test.rb
  test/integration/cross_surface_isolation_test.rb` -> 16 runs, 38 assertions, 0 failures.
- `bin/rubocop` on the two changed controllers -> no offenses.

Not run: the full suite. The changed surface is CSRF declaration and documentation only.
