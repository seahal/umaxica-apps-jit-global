# APP signup SMS timeout and stale retry

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- Before the new case, the delayed signup transport and SMS job files passed (18 runs, 100 assertions).
- A new case injects `Net::ReadTimeout` into the actual bound SMS job and observes its scheduled retry. The timeout itself preserves the current generation's expiry and unconsumed state. After explicit resend creates a replacement generation, the scheduled old job is performed and reaches no transport; the replacement generation and its own expiry remain unchanged and its code verifies. Its expiry is bounded by the parent Flow deadline.
- An initial test assertion incorrectly expected the new generation's OTP expiry to equal the previous generation's expiry and failed; the observed replacement expiry differed. The test was corrected to assert the parent deadline and preservation of the replacement generation during stale retry. This observation does not decide whether the specification requires the original OTP expiry rather than the parent expiry on explicit resend.
- The delayed transport, SMS job, concurrency and Telephone issuer files passed together (44 runs, 406 assertions). Scoped RuboCop and `git diff --check` passed. Timeout was injected; actual SNS, acceptance-before-timeout, full-duration timeout and browser behavior remain unverified.
