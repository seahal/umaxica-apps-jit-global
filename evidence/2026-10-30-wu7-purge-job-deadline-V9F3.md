# WU-7 preference purge job deadline

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- Added a public-job boundary test for a preference deadline one microsecond ahead of, equal to, and one microsecond behind the decision time. At equality and after, the job removed the row; before, it retained the row. The test substitutes a fixed value for `ComPreference.database_now` so the equality case is deterministic; it verifies the job's comparison and candidate selection, not the actual PostgreSQL clock implementation.
- Before the change, `PARALLEL_WORKERS=1 bin/rails test test/jobs/preference_lifecycle_job_test.rb` passed with 6 runs and 27 assertions. The first new run errored because `Integer#microsecond` is unavailable; using an exact rational second fixed it. The final run passed with 7 runs, 32 assertions, no failures, errors or skips. RuboCop passed on the test file.
- External holds, production execution, the full suite and WU-7 completion remain unverified. No migration was executed in this slice.
