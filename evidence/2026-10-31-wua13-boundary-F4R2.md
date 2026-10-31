# Signup birthdate boundary check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including earlier signup work.
- `PARALLEL_WORKERS=1 bin/rails test test/services/sign_up_eligibility_policy_test.rb test/models/concerns/has_birthdate_test.rb test/controllers/auth/app/up/emails_controller_test.rb:1719` passed: 31 runs, 220 assertions, no failures or errors. The policy tests include dates on either side of leap day, and the selected app signup case checks today, tomorrow and yesterday.
- This does not verify a completed ORG invitation signup; the current ORG invitation endpoint refuses provisioning pending Bureau migration.
