# Phase 18 notification audit and quality gates

- Date: 2026-09-21 UTC
- Scope: OTP email enqueue audit, focused/full regression, JavaScript suite, coverage gate
- External writes: none
- Provider access: no email, SMS, AWS, Cloudflare, or other external provider was contacted

## Implemented slice

The legacy OTP email adapter and the Noticed rollout adapter now record the successful enqueue
fact in Chronicle as `notification.delivery.email.enqueued`. The event is bound to the email
record and carries only the controlled purpose value. Recipient addresses, OTPs, verification
tokens, and message bodies are not included. Provider acceptance, delivery outcome, retry,
permanent failure, archive, and legal-retention policy were not invented.

## Verification

Focused OTP notification suite:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/adapters/otp_adapter_email_characterization_test.rb \
  test/adapters/otp_adapter_test.rb \
  test/adapters/otp_email_plaintext_boundary_test.rb \
  test/notifiers/notify/otp_notifiers_test.rb \
  test/services/otp_email_notifier_rollout_test.rb
```

Result: `33 runs, 109 assertions, 0 failures, 0 errors, 0 skips`.

Full Rails suite:

```text
bin/rails test
```

Result: `11475 runs, 73310 assertions, 0 failures, 0 errors, 6 skips`.

JavaScript suite:

```text
bun run test
```

Result: `85 files passed, 1065 tests passed`.

Static checks:

- changed-file RuboCop: 4 files inspected, no offenses;
- Brakeman 8.0.6: 0 errors, 0 security warnings;
- `git diff --check`: passed;
- frozen-plan validator: 70 canonical source rows and 70 FREQ rows, zero mapping errors,
  `result: PASS`.

Coverage command:

```text
COVERAGE=true bin/rails test test/
```

The Rails tests themselves completed with the full-suite result above, but the process exited 2
because the existing SimpleCov gates were below threshold: line 95.95% / 98.00% minimum, branch
75.00% / 90.00% minimum, method 90.94% / 95.00% minimum. No coverage threshold, exclusion,
assertion, or skip was changed.

## Remaining contract boundary

FREQ-0064 is improved but remains partial. Provider receipt/delivery/retry/permanent-failure
facts and approved retention/archive policy still require an owner and an approved external
contract. The repository does not claim those facts from enqueue success.

The legacy and Noticed email adapters were then adversarially rechecked for enqueue failure and
audit-write failure. The focused regression set completed with `15 runs, 68 assertions, 0
failures, 0 errors, 0 skips`, and the final full Rails suite completed with `11483 runs, 73355
assertions, 0 failures, 0 errors, 6 skips`. The six skips are existing suite skips.
