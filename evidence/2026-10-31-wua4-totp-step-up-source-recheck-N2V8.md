# WU-A4 TOTP Step-Up source recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The existing TOTP Step-Up verifier file initially passed (5 runs, 26 assertions). Injecting owner stop or credential revocation immediately after the real TOTP consumer accepted a code showed that the earlier code still wrote evidence (2 runs, 2 assertions, 2 failures).
- The verifier now reacquires and rechecks the source owner and locks/rechecks the owned TOTP before the existing Ticket binding check and evidence write, retaining source locks through the Ticket write. An unavailable owner or credential leaves the already-consumed TOTP window and pending Ticket without freshness.
- The TOTP verifier, independent device race and Base freshness files passed together (30 runs, 194 assertions, 0 failures, 0 errors, 0 skips). RuboCop passed for the operation and corrected formatting in the verifier test. The client Step-Up diagram and transition inventory were updated.
- Owner/credential state changes were injected synchronously under transactional fixtures. Independent source/ Ticket commit order, outer transactions and the complete credential-writer/version inventory remain unverified.
