# APP TOTP Step-Up admission test alignment

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting the checks.
- The focused TOTP controller file initially produced 5 runs, 9 assertions, 4 failures and no errors. Its fixtures posted to the now GET-only admission endpoint, so requests reached later assertions without an admitted Auth ceremony.
- Updated the four single-browser cases and both browser entries in the replay case to use HTTPS GET and assert successful admission. The method-denial case now also establishes a valid admission before checking the disallowed method. Existing page, invalid-code, revoked-authenticator and two-ceremony replay assertions remain.
- The file passed after the edit: 5 runs, 29 assertions, no failures, errors or skips. RuboCop and scoped `git diff --check` passed. The last change after the passing run was whitespace only. These integration tests do not establish real browser or deployed behavior.
- The full-suite result in `2026-10-31-two-full-suite-after-corrections-N5R8.md` predates this test change.
