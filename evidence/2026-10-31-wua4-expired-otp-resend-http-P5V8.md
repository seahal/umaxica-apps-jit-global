# APP signup expired OTP resend at HTTP boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the controllers, operations and tests.
- Before adding the new request cases, the operation deadline cases and adjacent Email/Telephone resend checks passed (8 runs, 56 assertions).
- Two public requests submit Email and Telephone resend at the respective existing OTP deadline with controlled Rails and database clock methods. Both returned the current HTTP 422, queued no corresponding delivery job, and preserved snapshots of the Flow, candidate, transaction and browser locator (2 runs, 12 assertions).
- The Email and Telephone signup controller files, operation deadline tests and delayed transport file passed together (147 runs, 1,385 assertions). Scoped RuboCop and `git diff --check` passed.
- The controller currently renders its general invalid-code copy for `closed_challenge`; this check does not establish that copy or 422 as the intended `two.md` §6.6 response. It also does not assert zero writes to every unrelated table, use a real browser or deliver mail/SMS.
