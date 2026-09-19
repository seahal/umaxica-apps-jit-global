# Keep CSRF Protection Off by Default in the Test Environment

## Status

Accepted (2026-08-31)

This record exists to close a recurring question. Treat it as settled: do not reopen "should
`bin/rails test` enable CSRF protection?" without new evidence that invalidates the reasoning below.

## Context

`config/environments/test.rb` sets `config.action_controller.allow_forgery_protection = false`. The
line previously carried the comment "Keep request forgery protection off by default so the existing
suite can migrate in batches", which reads as a temporary state and invites a periodic proposal to
flip it to `true`.

That reading is wrong, and the question has now been raised often enough to be worth recording.
Three facts drive the decision.

**Disabling it in test is the Rails default, not a deviation.** The generated
`config/environments/test.rb.tt` in `railties` ships `allow_forgery_protection = false`. The
application is following the framework, not working around it.

**Blanket-enabling it would buy far less than it appears to.** The application uses
`protect_from_forgery using: :header_or_legacy_token` (`app/controllers/application_controller.rb`).
Under the Rails 8.2 header-based strategy, a request that carries no `Sec-Fetch-Site` header over a
non-SSL connection verifies successfully - which is exactly the shape of an integration-test
request. Flipping the flag would therefore let most tests pass without exercising CSRF at all. The
result is the appearance of coverage rather than coverage.

**The real coverage is targeted, and it already exists.** CSRF behaviour is asserted by boundary
tests that construct the request shapes that actually matter:

- `test/controllers/protocol_controller_csrf_boundary_test.rb`
- `test/integration/social_completion_cross_host_csrf_test.rb`
- `test/integration/csrf_notification_emission_test.rb`
- `test/integration/preference_web_csrf_test.rb`

Against this, enabling the flag suite-wide would require reworking a large number of existing tests
for no meaningful gain in assurance. The cost is real and the benefit is close to zero.

## Decision

- `config/environments/test.rb` keeps `config.action_controller.allow_forgery_protection = false`.
  This is the deliberate, permanent setting for the test environment - not a migration state.
- CSRF verification remains **mandatory** in development and production. Neither environment may
  disable `allow_forgery_protection`, and no controller may use `skip_forgery_protection`.
- CSRF assurance in the test suite comes from targeted boundary tests that opt in explicitly, using
  the existing per-test helper (`with_forgery_protection`) or an equivalent. New CSRF-relevant
  behaviour is covered by adding such a test, never by changing the environment default.
- The comment on the setting states this decision and links here, so the line no longer reads as
  temporary.

## Consequences

- The recurring "turn CSRF on in `bin/rails test`" proposal is answered once, here.
- A CSRF regression that only a suite-wide flag would catch is, by the argument above, not a class
  of regression that flag would actually catch under `:header_or_legacy_token`. Genuine regressions
  are caught by the boundary tests, which must be extended whenever a new surface, verification
  strategy, or cross-host flow is introduced.
- If the forgery-protection strategy ever changes to one where a bare test request fails
  verification, the second argument above no longer holds and this record should be revisited. That
  is the specific condition that would justify reopening it.
