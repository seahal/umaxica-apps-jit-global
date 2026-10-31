# APP email sign-in Source cooldown disclosure probe

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the application and test.
- A temporary integration test in `test/controllers/auth/app/in/emails_controller_test.rb` exercised the existing admitted session: a verified bound ClientEmail with `otp_last_sent_at` set to the current time returned HTTP 429; an absent address returned a redirect and stored dummy authentication state. The probe passed (1 run, 8 assertions) and was removed afterward.
- This establishes differing outcomes under the stated Source-only cooldown precondition; it does not establish arbitrary remote induction of that precondition, production deployment behavior, or the correct replacement response contract.
- Separately, the WU-A13 APP signup boundary test passed (1 run, 20 assertions) for today, tomorrow, and yesterday. The authentication checklist's obsolete underage-halt assertion was corrected to match the checked controller and accepted one-day rule. This check does not establish all age-restricted features.
