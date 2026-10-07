# Signup OTP flow binding regression

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- Worktree: inherited and current uncommitted implementation, migrations and tests.
- Database scope: owned `20261007fresh3` isolated manifest; one Rails test process at a time.

The nine-file signup/finalization/Source-audit probe at seed 63929 had 67 runs, 680 assertions,
36 failures and two errors. Four old OTP endpoint files bypassed admission; Contact audit tests
assumed an externally provisioned Chronicle security policy. A COM interrupted-distribution
recovery assertion also failed and remains retained as the owner's deferred Non-Goal, not repaired,
skipped or counted as a pass.

The four OTP files now arrange public admission issue/attach/confirm/redeem and reuse the signed
flow binding returned by candidate creation. This exposed app/com telephone success redirects
dropping that binding. Both production redirects now carry the existing binding to the next guard
checkpoint. The competing email destination test now verifies D-86's independent real candidate,
unchanged effective owner and no OTP advancement; it no longer asserts the retired cross-flow dummy
shortcut. No authorization, candidate limit or constraint was weakened.

Chronicle test setup explicitly arranges its existing `security` policy (365 days, nonpermanent).
The accepted operator-capability ADR requires operational provisioning; missing production policy
remains an explicit failure. No migration/seed fallback was introduced.

```bash
bin/rails test test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb \
  test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb \
  test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb \
  test/controllers/auth/com/sign/up/check/telephone/otps_controller_test.rb \
  test/jobs/contact_audit_delivery_job_test.rb --seed 63929
```

Final result: **40 runs, 365 assertions, zero failures, errors or skips**. Earlier iterations
reproduced 400 missing-admission refusals, then 409 missing-binding refusals; once those fixtures
were current, the missing production redirect binding failed before the fix. This focused result
does not certify the deferred COM recovery assertion or the full candidate/lifecycle/timing matrix.
