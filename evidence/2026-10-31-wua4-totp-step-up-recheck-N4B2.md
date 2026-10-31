# WU-A4 TOTP Step-Up post-verification recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The existing TOTP Step-Up verification file passed before the change (4 runs, 22 assertions). A new injected timing case revoked the device immediately after the real TOTP consumer accepted its code; the earlier code still recorded evidence (1 run, 1 assertion, 1 failure).
- After source verification succeeds, the operation now rechecks the owner binding, current usable device, token, session and pending/unexpired parent under Ticket locks and records evidence while those locks are held. If the check refuses, the already-consumed TOTP window remains consumed and the parent stays pending.
- The Step-Up verification and TOTP enrollment finalizer files passed after the change (11 runs, 93 assertions, 0 failures, 0 errors, 0 skips). RuboCop passed after correcting formatting. The client Step-Up diagram and inventory were updated.
- The timing case uses a synchronous injected revocation with transactional fixtures; it does not establish both independent-connection commit orders, behavior under an enclosing Ticket transaction, or all actor/credential changes between source verification and later Root issuance. WU-A10 credential-version and TOTP enrollment finalization order/audit remain open.
