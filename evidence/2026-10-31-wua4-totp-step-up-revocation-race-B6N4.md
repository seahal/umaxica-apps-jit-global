# WU-A4 TOTP Step-Up revocation during source verification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting implementation and tests.
- A nontransactional test uses a separate worker connection and pauses immediately after the real TOTP consumer accepts its code. The main connection commits device revocation before releasing the worker. The source TOTP window commits consumed; the Ticket recheck refuses, the parent remains pending and no token freshness is written. Synthetic records are removed by the test.
- The focused race passed (1 run, 5 assertions). After formatting, the race, TOTP verifier and freshness operation files passed (27 runs, 173 assertions, 0 failures, 0 errors, 0 skips). RuboCop corrected the new test's formatting.
- This checks only revocation committed before the post-source Ticket recheck; it does not establish the evidence-first ordering, enclosing Ticket transactions, HTTP delivery or simultaneous owner/credential changes. The SMTP delivery eligibility-to-send gap and transport deadline remain open.
