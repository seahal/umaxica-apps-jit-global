# WU-A4 Passkey Step-Up source recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- APP/ORG Passkey Step-Up files initially passed (14 runs, 76 assertions). Tests that changed each owner to `RESERVED` during real signature verification showed that the earlier code still recorded evidence (2 runs, 2 assertions, 2 failures).
- After signature verification, the operation reacquires the source owner lock, verifies owner login eligibility and locks/rechecks the active owned Passkey, then holds those locks while the existing Ticket device/session/parent recheck and evidence write complete. Additional injected cases check a Passkey revoked during signature verification. Each case leaves the challenge burned and parent pending, with no token freshness.
- APP/ORG Passkey and freshness files passed together after formatting (39 runs, 238 assertions, 0 failures, 0 errors, 0 skips). RuboCop passed for the implementation and corrected formatting in the tests. Both Step-Up diagrams and their transition inventory were updated.
- These injections run under transactional fixtures and do not prove independent source/ Ticket commit order, outer transaction behavior, all credential writers' locking discipline or deployed paths. WU-A10 credential version remains unimplemented.
