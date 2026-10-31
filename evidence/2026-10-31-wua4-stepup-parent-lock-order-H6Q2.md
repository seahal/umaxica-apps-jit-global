# Step-Up parent and session lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- Code inspection found cancellation taking the parent transaction before the Step-Up session, while Email challenge writers and Email/TOTP/Passkey verification paths took those two locks in the reverse order. Email delivery-result recording can run without the cancellation path's token lock.
- Updated those paths to acquire the parent transaction before the session. Before the change, the narrow Email verifier file passed (6 runs, 38 assertions). Afterward, the Email issuer, verifier and delivery, TOTP verifier and device-race, Passkey verifier, and cancellation operation files passed: 44 runs, 245 assertions, 0 failures, 0 errors, 0 skips. `git diff --check` passed for the five changed implementation files.
- A two-connection deadlock reproduction and a complete inventory of other lock paths were not performed. The external email transport remains outside eligibility locks; this change does not fix its release-after-check race. The full suite was not run.
