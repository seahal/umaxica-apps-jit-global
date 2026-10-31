# WU-A4 TOTP enrollment start versus device revocation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- A nontransactional test uses independent database connections. One transaction holds the synthetic device row and revokes it; the enrollment worker is observed waiting on a PostgreSQL lock before revocation commits. After commit, the worker raises the device-unavailable error, creates no candidate or child transaction, and leaves the parent pending and attempt count at zero. The synthetic records are deleted by the test.
- The focused race passed (1 run, 6 assertions). After formatting, the race and TOTP enrollment query, issuer, verification and finalizer operation files passed together (21 runs, 257 assertions, 0 failures, 0 errors, 0 skips). RuboCop corrected formatting in the newly added test.
- This checks revocation-first enrollment start only. Enrollment-first ordering, candidate display and verification races, actual HTTP concurrency, and finalization's separate cross-database ordering and audit gaps remain unverified.
