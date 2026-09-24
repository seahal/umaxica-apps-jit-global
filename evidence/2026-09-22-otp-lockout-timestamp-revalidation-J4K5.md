# OTP lockout timestamp revalidation

Date: 2026-09-22
Branch: `feature`
HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: contained pre-existing and related uncommitted changes; no unrelated changes were reset.

## Disposition

`security-otp-attempts-atomic-increment.md` was marked `ALREADY_SATISFIED`. The current shared
`OtpLockable` implementation already performs the required row-locked increment and writes the
finite lockout timestamp at the threshold. It preserves that first timestamp after later failed
attempts, retains the database-clock boundary, and keeps the existing count-based lockout behavior.
Email and telephone models both include this concern; no duplicate implementation or migration was
introduced.

## Verification

Command:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/concerns/otp_lockable_test.rb test/models/concerns/email_test.rb test/models/concerns/telephone_test.rb test/models/client_email_test.rb test/models/client_telephone_test.rb
```

Result: 153 runs, 459 assertions, 0 failures, 0 errors, 0 skips.

The run used the repository's Compose-backed test PostgreSQL/Valkey environment. No production,
shared, AWS, Cloudflare, or GitHub state was accessed or changed. No application code, migration,
test weakening, skip, or mock was added for this revalidation.
