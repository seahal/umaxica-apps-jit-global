# Out-of-Band OTP Lifetime Revalidation

Date: 2026-09-22

Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

The worktree contained pre-existing and concurrent uncommitted changes. This
verification did not reset, stash, stage, commit, or discard them. No AWS,
Cloudflare, production, shared database, or external delivery provider was
contacted.

## Scope

The out-of-band OTP policy was revalidated against the current implementation.
Authentication OTPs and SMS signup confirmation use the finite ten-minute
upper bound. Email signup confirmation is treated as contact confirmation but
uses the same shorter bound. Purpose-specific constants remain distinct in
name while sharing `CommonOtpPolicy::MAX_OOB_TTL`.

## TDD and focused verification

Before adding the shared policy constant, the new public contract test failed
as expected:

```text
PARALLEL_WORKERS=1 bin/rails test test/services/sign_otp_ceremony_test.rb
NameError: uninitialized constant CommonOtpPolicy::MAX_OOB_TTL
13 runs, 56 assertions, 0 failures, 1 error, 0 skips
```

After the policy implementation and public boundary tests were added:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/services/sign_otp_ceremony_test.rb \
  test/services/sign/telephone_otp_delivery_test.rb

15 runs, 77 assertions, 0 failures, 0 errors, 0 skips
```

The new behavior tests cover successful verification immediately before the
ten-minute boundary and rejection at the boundary. Existing public tests cover
database-clock expiry, resend cooldown, failed-attempt persistence, and
one-time consumption.

The broader app/com signup OTP controller set passed:

```text
47 runs, 298 assertions, 0 failures, 0 errors, 0 skips
```

The full Rails suite passed after the change:

```text
bin/rails test

11536 runs, 73426 assertions, 0 failures, 0 errors, 8 skips
```

The eight skips were pre-existing; no skip was added for this change.

Static verification also passed:

```text
bin/rubocop app/values/common_otp_policy.rb \
  test/services/sign_otp_ceremony_test.rb \
  test/services/sign/telephone_otp_delivery_test.rb

3 files inspected, no offenses detected

ruby -c app/values/common_otp_policy.rb
Syntax OK

ruby -c test/services/sign_otp_ceremony_test.rb
Syntax OK

git diff --check
```

After the review corrected a stale `CommonOtp` API comment, the focused
ceremony/delivery suite was rerun and still passed with 15 runs and 77
assertions. RuboCop then inspected the four affected Ruby files, with no
offenses, and the concern syntax check returned `Syntax OK`.

## Disposition

`ALREADY_SATISFIED`: the current OTP expiry behavior already met the ten-minute
security bound. The implementation change only made the shared upper-bound
policy explicit and added public boundary coverage. No dry-run, preview, or
simulation path was introduced. No workflow-ticket lifetime was shortened
merely to satisfy the OTP secret lifetime.
