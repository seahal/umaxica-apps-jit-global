# PublicController CSRF Test

Status: `STALE_REQUIREMENT` for the historical controller names; current CSRF
coverage is `ALREADY_SATISFIED` at the active Base/Auth controller boundaries
(revalidated 2026-09-22).

Extracted from `plans/active/public-controller-base-plan.md` during archive.

## Problem

The historical plan specified that `protect_from_forgery` must be verified for
`Acme::PublicController`, `Sign::PublicController`, and `Jump::PublicController`.
Those controller classes do not exist in the current tree. The current
architecture uses surface-specific controller bases and explicit CSRF strategy
declarations instead; adding compatibility controller classes or production
routes solely to satisfy this historical plan would be scope drift.

The active contract remains that unsafe browser requests are protected by Rails
forgery protection, with the repository's explicit Rails 8.2
`:header_or_legacy_token` strategy except for reviewed protocol/telemetry
boundaries. Rails CSRF protection was not weakened.

## Acceptance

The current replacement verification covers the active public-controller
boundaries and the repository-wide strategy inventory:

- Base and Auth test-only POST boundaries reject a cross-site request without a
  CSRF token with 422 and accept a valid token.
- Every current `protect_from_forgery` declaration explicitly names its
  verification strategy.
- The active strategy is the hybrid Rails 8.2 strategy, with only the reviewed
  header-only exception and the bounded CSP telemetry exception.
- No production route or controller is added just for this historical test.

The historical per-class `Acme`/`Sign`/`Jump` acceptance is retired because
those classes are absent and no current route can exercise them.

## Related

- `app/controllers/acme/public_controller.rb`
- `app/controllers/sign/public_controller.rb`
- `app/controllers/jump/public_controller.rb`

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/base/public_controller_test.rb \
  test/controllers/auth/public_controller_test.rb \
  test/security/invariants/csrf_verification_strategy_invariant_test.rb \
  test/unit/security/skip_forgery_protection_usage_test.rb

20 runs, 38 assertions, 0 failures, 0 errors, 0 skips
```

Evidence: `evidence/2026-09-22-csrf-public-boundary-revalidation-Q1R2.md`.
