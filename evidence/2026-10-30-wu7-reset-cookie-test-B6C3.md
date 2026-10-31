# WU-7 reset cookie test

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The com reset case inserted a host-only language cookie alongside the existing domain-scoped cookie of the same name. Adding an explicit response assertion showed that duplicate-cookie protection returned 400, before reset.
- The test now leaves the issued com language cookie in place and asserts the reset response. The three app, org and com reset-cookie cases passed: 3 runs, 24 assertions, zero failures, errors or skips. Existing separate com reset and cookie-tossing tests cover their respective behaviors.
- Three other com settings-screen cases observed in the same selection remain under investigation. Full-suite comparison was not re-run in this slice.
