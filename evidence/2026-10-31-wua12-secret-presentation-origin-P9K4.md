# Secret presentation form referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- The APP Base and Auth telephone-signup Secret presentation responses now use `strict-origin`, and their shared HTML sets the same meta policy. The existing CSRF-protected confirmation and cancellation forms are unchanged.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/app_secret_signup_journey_test.rb` passed: 24 runs, 1465 assertions. The focused Base issuance-bound presentation and confirmation case passed: 1 run, 12 assertions. The CSRF verification strategy and standard CSRF invariant files passed: 6 runs, 12 assertions.
- The manual Base Secret login journey reached its new header/meta assertions but later failed at an existing 401 instead of its expected redirect: 1 run, 30 assertions, 1 failure. The same test failed at that later point before the change and is in `plans/2026-10-28-baseline-failing-tests.md`.
- `git diff --check` passed. RuboCop found four offenses on pre-existing lines 67 and 93–94 of the signup journey; no offenses were reported in the other checked Ruby files. A real browser run of these specific Secret forms and cross-site/absent-token requests against these specific forms were not performed.
