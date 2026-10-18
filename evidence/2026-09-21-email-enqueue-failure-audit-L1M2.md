# Email enqueue failure audit boundary

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- External writes: none

## Scope

This slice closes the repository-side notification-audit gap for OTP email enqueue failures.
It does not add a provider receipt ledger or infer provider delivery from a queued email.

The legacy mailer and Noticed adapter now record a sanitized
`notification.delivery.email.enqueue_failed` Chronicle fact when enqueue/issue raises, then
re-raise the original delivery exception. Successful enqueue remains a separate
`notification.delivery.email.enqueued` fact. If the audit write itself fails after the email was
queued, the failure is diagnostic only; the adapter does not report the already-queued email as a
second delivery failure that could cause duplicate delivery.

No recipient, OTP, verification token, message body, or exception message is persisted in the
audit metadata. Only the existing email record is used as the Chronicle subject and the exception
class is used as the failure reason.

## TDD and verification

The new tests were run before the implementation and failed for the intended reasons:

- no email enqueue-failure Chronicle row was written;
- an audit persistence exception escaped after the delivery had already been queued.

Focused verification after implementation:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/adapters/otp_adapter_email_characterization_test.rb \
  test/adapters/otp_email_adapter_test.rb \
  test/adapters/otp_email_notifier_adapter_test.rb \
  test/security/audit_record_integrity_test.rb
```

Result: `17 runs, 75 assertions, 0 failures, 0 errors, 0 skips`.

Targeted static checks:

```text
bundle exec rubocop \
  app/adapters/otp_adapter.rb \
  app/adapters/otp_email_adapter.rb \
  app/adapters/otp_email_notifier_adapter.rb \
  test/adapters/otp_adapter_email_characterization_test.rb \
  test/adapters/otp_email_adapter_test.rb \
  test/adapters/otp_email_notifier_adapter_test.rb \
  test/security/audit_record_integrity_test.rb
git diff --check
```

Result: seven files inspected with no offenses; `git diff --check` passed.

Full Rails verification:

```text
bin/rails test
```

Result: `11481 tests, 73347 assertions, 0 failures, 0 errors, 6 skips`.
The skips are existing suite skips; none was added by this slice.

After adding the equivalent failure and audit-write-failure coverage for the Noticed adapter, the
focused verification was rerun:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/adapters/otp_adapter_email_characterization_test.rb \
  test/adapters/otp_email_notifier_adapter_test.rb \
  test/security/audit_record_integrity_test.rb
```

Result: `15 runs, 68 assertions, 0 failures, 0 errors, 0 skips`.

The final full Rails verification was then rerun:

```text
bin/rails test
```

Result: `11483 tests, 73355 assertions, 0 failures, 0 errors, 6 skips`.

The six skips are existing suite skips; none was added by this slice.

Additional static verification after the final test run:

```text
bundle exec brakeman --quiet --no-exit-on-warn --no-exit-on-error
```

Result: Brakeman 8.0.6, Rails 8.2.0.alpha, 0 errors, 0 security warnings.
The repository wrapper `bin/brakeman` was also attempted, but its mandatory latest-release check
failed before scanning because no latest release metadata was available to the bundled client
(`NoMethodError` in `Brakeman.ensure_latest`). The direct bundled scan is the completed scan
result; no network or external service was used to bypass it.

The adjacent Valkey URL parser's ASCII-comment offense was corrected without changing behavior,
and the settings cache was subsequently moved to the existing thread-safe map primitive. A later
repository-wide RuboCop run inspected 4,773 files and reported no offenses; no lint disable or
configuration relaxation was added.

## Remaining boundary

Provider acceptance, delivery outcome, retry, bounce, and permanent-failure facts for email still
require an approved provider callback contract, owner, and retention policy. No external provider,
Cloudflare, AWS, production database, or live recipient was accessed.
