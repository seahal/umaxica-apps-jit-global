# Leap-day age consistency

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the implementation tested here.
- The focused `age_on` leap-day test first failed on 2025-02-28: expected 13, observed 12 (1 run, 2 assertions, 1 failure).
- After matching the canonical anniversary calculation, `PARALLEL_WORKERS=1 bin/rails test test/models/concerns/has_birthdate_test.rb test/services/age_eligibility_test.rb test/services/sign_up_eligibility_policy_test.rb` passed: 47 runs, 230 assertions, 0 failures, 0 errors, 0 skips. The new case checks the day before, the anniversary and the day after for each model used by the shared test.
- This does not verify the ORG invitation completion path or feature-owner age restrictions. The full suite was not run.
