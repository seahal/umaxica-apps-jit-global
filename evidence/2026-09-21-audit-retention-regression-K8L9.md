# Audit and retention regression slice

- Date: 2026-09-21 UTC
- Scope: FREQ-0064 audit-record and retention-hold regression coverage
- External writes: none; no AWS, Cloudflare, provider, production, shared database, email, or SMS service was contacted
- Environment: Rails tests used `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the approved test database preparation allowlist

## Implementation

Added public-behavior regression coverage for:

- durable authentication security audit records without raw token, OTP, refresh-token, or authorization-code values;
- email enqueue audit records bound to the email record and controlled purpose only;
- active retention holds preserving eligible Client rows and recording blocked privacy-erasure state;
- released retention holds no longer blocking an otherwise eligible purge.

No provider receipt, delivery, retry, permanent-failure, archive, or legal-retention contract was
invented. `RetentionPurgeJob` remains an explicit allowlist with bounded batches and hold-aware
selection. A new dry-run output/job-argument contract was not added without an approved shape.

## Verification

The first focused attempt without the required environment failed before Rails database setup with
`VALKEY_KVS_HOST is required`; no application or configuration workaround was made. The same
focused command was then run with the configured Compose PostgreSQL/Valkey network.

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/security/audit_record_integrity_test.rb \
  test/jobs/retention_hold_purge_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/adapters/otp_adapter_email_characterization_test.rb
```

Result: `24 runs, 116 assertions, 0 failures, 0 errors, 0 skips`.

```text
bin/rails test
```

Result: `11479 runs, 73335 assertions, 0 failures, 0 errors, 6 skips`.

After a formatting-only correction to the retention-hold test, the two newly added files were
rerun in the configured test environment:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/security/audit_record_integrity_test.rb \
  test/jobs/retention_hold_purge_test.rb
```

Result: `4 runs, 24 assertions, 0 failures, 0 errors, 0 skips`.

Targeted RuboCop inspected both new test files with no offenses. `git diff --check` passed. The
frozen-plan validator reported 70 source rows, 70 FREQ rows, zero mapping errors, and `result:
PASS`.

## Remaining boundary

FREQ-0064 remains partial because provider acceptance/delivery/retry/permanent-failure facts and
approved retention/archive policy require an owner and an approved external contract. The
repository-side enqueue and hold-aware regression facts above are verified; the unapproved
provider/archive contract is not claimed.
