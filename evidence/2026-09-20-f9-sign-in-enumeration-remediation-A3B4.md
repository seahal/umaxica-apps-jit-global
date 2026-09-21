# F9 sign-in enumeration remediation

- Date: 2026-09-20
- Scope: app/com email sign-in create requests
- Finding: the prior fresh-session path returned a registered-address cooldown response while an unregistered address could continue, because the uniform cooldown lived only in the browser session.

## Change

Both sign-in controllers now apply a Rails server-side rate-limit bucket keyed by the normalized
email blind index before account lookup. The existing cooldown response body and status are used,
so the public contract remains the same. Turnstile is evaluated once in an earlier callback; only a
successful Turnstile request can reserve the address-wide bucket. Invalid Turnstile requests remain
subject to the existing IP limits and cannot reserve a valid address bucket.

## Verification

- RED: the fresh-session app enumeration test reproduced the oracle: registered second request was
  `429`, while unregistered remained `302`.
- GREEN focused: `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/in/emails_controller_enumeration_test.rb test/controllers/auth/com/in/emails_controller_enumeration_test.rb` — 3 runs, 8 assertions, 0 failures, 0 errors, 0 skips.
- Affected regression set: `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/app/in/emails_controller_extra_test.rb test/controllers/auth/app/in/emails_controller_enumeration_test.rb test/controllers/auth/com/in/emails_controller_test.rb test/controllers/auth/com/in/emails_controller_enumeration_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign_in_otp_resender_failures_test.rb test/integration/auth_endpoint_burst_rate_limit_test.rb` — 119 runs, 518 assertions, 0 failures, 0 errors, 0 skips.
- Static analysis: `bundle exec rubocop app/controllers/auth/app/sign/in/emails_controller.rb app/controllers/auth/com/sign/in/emails_controller.rb test/controllers/auth/app/in/emails_controller_enumeration_test.rb test/controllers/auth/com/in/emails_controller_enumeration_test.rb` — 4 files inspected, no offenses.

## Remaining scope

The sign-up email/telephone cooldown asymmetry was remediated in a follow-up slice. The recovery-
style OTP paths identified in the preceding F9 review remain unverified.
