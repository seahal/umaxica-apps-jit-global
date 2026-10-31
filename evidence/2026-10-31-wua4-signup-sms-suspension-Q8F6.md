# APP signup SMS suspension response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- A narrow pre-change regression selection passed (3 runs, 29 assertions). Public initial and resend tests with injected SMS suspension then both reproduced HTTP 422 instead of unavailable (2 runs, 2 failures).
- The Telephone delivery issuer now distinguishes a transport rejection after a current guard from a stale guard refusal. The controllers handle the former using the existing 503 unavailable page. The focused initial/resend tests passed (2 runs, 20 assertions), observing the retained generation, no queued SMS, unavailable copy and existing cancel action.
- The Telephone signup controller, signup issuer/guard/concurrency and outbound SMS audit files passed together (95 runs, 1,003 assertions). Scoped RuboCop and `git diff --check` passed.
- Suspension was injected. Actual provider failure, browser execution and recovery after the channel resumes were not exercised. The signup OTP page still has no resend button, and the existing stale-guard result's complete §6.6 mapping remains open.
