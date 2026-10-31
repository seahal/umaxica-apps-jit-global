# WU-A13 signup birthdate test contract

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Existing staged, unstaged and untracked changes
affected this run. No commit was made.

Replaced the obsolete under-thirteen HALTED journey with the accepted one-day signup contract.
The HTTP journey now refuses today and tomorrow with 422 without advancing the checkpoint, then
accepts yesterday, completes signup and redirects to sign-in. It does not travel backward during
the live authentication flow. Separate public-policy assertions cover yesterday/today/tomorrow
on 2024-02-28, 2024-02-29 and 2024-03-01 on app and org, including the formerly refused
2011-03-01 birthdate as eligible.

- Focused HTTP case: 1 run, 20 assertions, no failures or errors.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/up/emails_controller_test.rb
  test/services/sign_up_eligibility_policy_test.rb`: 72 runs, 622 assertions, no failures,
  errors or skips.
- RuboCop initially found one hash-layout offense, which was corrected. The final check reported
  no offenses in the two files; `git diff --check` passed.

This fixes an obsolete WU-A13 test expectation. It does not establish a production handoff defect
when clocks move backward, full-suite success, or WU-7 closure. No application implementation or
database schema was changed.
