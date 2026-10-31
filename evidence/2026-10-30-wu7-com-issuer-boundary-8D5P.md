# WU-7 com issuance boundary

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

The legacy `issue_access_token_from` method previously had a com branch which could rotate a generation and emit a com JWT outside the com write boundary. It now rejects a com preference before rotation or payload generation; the legacy com issuance method was removed. The existing authorized write boundary remains the application caller of com issuance preparation and emission. A static guard checks direct call sites in `app/`; it does not prove the absence of arbitrary dynamic calls or isolate keys within one process.

Before the change, the com write journey, initialization and boundary tests passed: 71 runs, 655 assertions. The first attempted command used a nonexistent test path and was corrected before that run. After the change, those tests plus the com Web Push API and new static guard passed: 83 runs, 747 assertions, no failures, errors, or skips. RuboCop passed for the changed concern and static guard.

The realm-specific keysets, distribution, complete writer inventory and lifecycle schema remain incomplete. No key material was created, copied or distributed.
