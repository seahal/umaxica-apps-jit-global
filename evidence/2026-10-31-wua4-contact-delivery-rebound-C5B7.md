# Contact registration OTP delivery device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A local test supplied an earlier token lookup after changing the token's persisted device association. Before the fix, the first Email case failed because delivery proceeded (1 run, 1 assertion, 1 failure); the loop did not reach the Telephone case before that failure.
- Both registration delivery guards now require the locked token to name the locked device. The focused Email/Telephone test passed with 1 run and 4 assertions. The delivery, resend and Email bootstrap/guard files passed together with 82 runs and 1,098 assertions; RuboCop passed for the changed files.
- The test uses transactional fixtures and a stubbed token lookup to model the stale-read window. It does not establish normal production token reassignment, independent-connection timing, actual email/SMS delivery, transport deadlines or the full XDB-14 commit-failure matrix.
