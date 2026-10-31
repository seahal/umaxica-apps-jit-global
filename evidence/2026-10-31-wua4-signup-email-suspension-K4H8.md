# APP signup asynchronous Email suspension

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the application and tests.
- Before the new case, the delayed signup transport and notifier files passed (18 runs, 88 assertions).
- A new integration case issues an APP signup Email OTP, runs the actual encrypted Noticed delivery job with the Email suspension decision injected, and observes no mail delivery. The OTP generation and original expiry remain unchanged and unconsumed; verification using the in-process test code still succeeds without a delivery receipt (1 run, 8 assertions).
- The delayed transport, notifier, suspension interceptor, signup delivery guard and Email issuer files passed together (50 runs, 389 assertions). Scoped RuboCop and `git diff --check` passed.
- The suspension decision was injected and the code was supplied by the test issuer; no recipient obtained it during suspension. A real SMTP server, browser recovery, sign-in, Step-Up and the complete XDB-14 matrix are not established by this test.
