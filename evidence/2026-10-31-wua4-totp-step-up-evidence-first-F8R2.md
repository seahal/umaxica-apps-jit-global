# WU-A4 TOTP Step-Up evidence-first device race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- A nontransactional test pauses the real evidence writer after it has acquired the Ticket locks. A separate connection attempts device revocation and is observed waiting on a PostgreSQL lock. After the evidence writer is released, verification commits, then revocation commits; the Ticket is verified, the device is revoked and no token freshness was issued. The test deletes its synthetic records.
- The focused concurrency file passed (2 runs, 12 assertions). After formatting, the concurrency, TOTP verification and freshness files passed (28 runs, 180 assertions, 0 failures, 0 errors, 0 skips). RuboCop corrected formatting in the concurrency test.
- This establishes the tested evidence-first ordering and complements the previously recorded revocation-first case. It does not itself attempt Base finalization after revocation, test an enclosing Ticket transaction or cover all actor/credential changes.
