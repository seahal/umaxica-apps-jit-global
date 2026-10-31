# APP Email sign-in resend ordering inspection

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had substantial uncommitted changes that affected the inspected code and test.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb:343` passed: 1 run, 15 assertions, no failures, errors, or skips.
- The exercised test checks that its refused requests do not rotate the generation or deliver mail; it controls the ceremony expiry and does not inspect occurrence records or isolate the OTP deadline.
- Inspection of `SignInOtpResender#call` shows occurrence creation/reservation before `issue_and_send!` checks the current challenge. `two.md` §6.2 XDB-14 specifies the generation commit before cooldown commit. The current challenge check and the later issuance parent lock are separate operations; concurrent deadline or cancellation behavior was not tested here.
- The ordering, refusal-side occurrence changes, concurrency, external transport and any corrective implementation remain unverified or unfinished.
