# Keep CSRF Protection Off by Default in the Test Environment

## Status

Accepted (2026-08-31); Context and Consequences amended (2026-09-20)

This record exists to close a recurring question. Treat it as settled: do not reopen "should
`bin/rails test` enable CSRF protection?" without new evidence that invalidates the reasoning below.

The 2026-09-20 amendment corrects a factual error in the original Context. It does not change the
decision.

## Context

`config/environments/test.rb` sets `config.action_controller.allow_forgery_protection = false`. The
line previously carried the comment "Keep request forgery protection off by default so the existing
suite can migrate in batches", which reads as a temporary state and invites a periodic proposal to
flip it to `true`.

That reading is wrong, and the question has now been raised often enough to be worth recording.

**The test environment is deliberately different from development and production.** CSRF
verification is mandatory in development and production. In the test environment it is off by
default, and that difference is intentional and permanent. It is not a migration state, not
technical debt, and not a gap awaiting closure.

**Disabling it in test is the Rails default, not a deviation.** The generated
`config/environments/test.rb.tt` in `railties` ships `allow_forgery_protection = false`. The
application is following the framework, not working around it.

**Correction (2026-09-20).** This record previously argued that blanket-enabling the flag would buy
nothing, because a request with no `Sec-Fetch-Site` header over a non-SSL connection verifies
successfully. That is the behaviour of the `:header_only` strategy, which is the `load_defaults
"8.2"` default but *not* what this application uses. Every surface root overrides the strategy to
`:header_or_legacy_token`, and under that strategy a request with a missing or `none`
`Sec-Fetch-Site` falls back to `any_authenticity_token_valid?` and is **rejected** without a valid
same-session token (`verified_with_legacy_token?`,
`actionpack/lib/action_controller/metal/request_forgery_protection.rb`). A bare integration-test
request therefore fails verification rather than passing it.

The correction inverts that argument but not the decision. Enabling the flag suite-wide would
genuinely exercise CSRF; the objection is cost, not futility. Doing so would require threading a
valid authenticity token through a large number of existing tests whose subject is not CSRF, and
the assurance gained would duplicate what the boundary tests below already provide at a fraction of
the cost.

**The real coverage is targeted, and it already exists.** CSRF behaviour is asserted by boundary
tests that construct the request shapes that actually matter:

- `test/controllers/protocol_controller_csrf_boundary_test.rb`
- `test/integration/social_completion_cross_host_csrf_test.rb`
- `test/integration/csrf_notification_emission_test.rb`
- `test/integration/preference_web_csrf_test.rb`

## Decision

- `config/environments/test.rb` keeps `config.action_controller.allow_forgery_protection = false`.
  This is the deliberate, permanent setting for the test environment, and there is no plan to change
  it. A proposal to flip it suite-wide is answered by this record.
- The test environment's CSRF behaviour is expected to differ from development and production. That
  divergence is the decision, not a defect to reconcile.
- CSRF verification remains **mandatory** in development and production. Neither environment may
  disable `allow_forgery_protection`, and no controller may use `skip_forgery_protection` outside the
  single recorded CSP-report exception.
- **Per-test opt-in is explicitly permitted and encouraged.** Nothing here discourages an individual
  test from enabling forgery protection and asserting real token verification. A test that needs to
  verify CSRF behaviour should do so, using the existing per-test helper
  (`with_forgery_protection`) or an equivalent. New CSRF-relevant behaviour is covered by adding
  such a test, never by changing the environment default.
- The comment on the setting states this decision and links here, so the line no longer reads as
  temporary.

## Consequences

- The recurring "turn CSRF on in `bin/rails test`" proposal is answered once, here. The answer is
  no, and it is not expected to change.
- Enabling the flag suite-wide *would* catch regressions rather than silently passing, so the case
  against it rests on cost and duplication, not on the flag being inert. Reviewers should not
  reinstate the older, incorrect "it would not catch anything" argument.
- Genuine regressions are caught by the boundary tests, which must be extended whenever a new
  surface, verification strategy, or cross-host flow is introduced. That obligation is the price of
  keeping the default off, and it is the part worth enforcing in review.
- If the application ever moves from `:header_or_legacy_token` to `:header_only`, the older argument
  becomes true rather than false: a bare non-SSL test request would then verify successfully, making
  a suite-wide flag actively misleading. That change strengthens this decision; it does not reopen
  it.
