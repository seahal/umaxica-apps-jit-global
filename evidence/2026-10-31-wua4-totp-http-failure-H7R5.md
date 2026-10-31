# WU-A4 TOTP rename dependency failure over HTTP

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes in the
worktree affected this run. The test used local test databases; production and Neon were not targeted.

Extended the authenticated, target-bound TOTP rename HTTP journey with an injected operation
dependency failure. The controller returned 503, left the title unchanged and retained the
Step-Up evidence. The same journey then performed a successful rename and returned to the TOTP
list. Focused result: 1 run, 8 assertions, no failures, errors or skips.

This checks public response mapping, not a real end-to-end database outage. Same-transaction
audit and other XDB-04 race conditions remain unresolved; `four.md` records the audit shape issue.
