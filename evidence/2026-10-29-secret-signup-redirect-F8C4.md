# Secret signup journey redirect investigation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Updated the Visa authorization step in `test/integration/app_secret_signup_journey_test.rb` to expect the current HTTP 303 instead of an obsolete confirmation form. This advances all 24 parameterized cases beyond the previous failure.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/app_secret_signup_journey_test.rb:38` ran 24 cases and 72 assertions, with 24 failures, 0 errors and 0 skips. All reached the later telephone signup GET, which returned HTTP 400 rather than 200; the intervening legacy admission sequence requires further repair. No successful end-to-end journey is claimed.
- Test database preparation was used; no production persistence operation or external write was performed.
