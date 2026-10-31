# Email Step-Up delivery and release

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the tested implementation.
- The nontransactional race paused the mailer and attempted Email release on another connection. Before the change, release completed during the paused delivery (1 run, 1 assertion, 1 failure). After the change, the release was observed waiting, delivery completed, release committed, and the delivered code was refused.
- An initial combined test run produced 18 fixture foreign-key errors. Investigation identified three sets of synthetic rows left by earlier failed `base_step_up_admission_reference_race_test` runs: an exception re-raised by thread join had interrupted cleanup. Only those explicitly identified synthetic rows were removed, and test cleanup was corrected.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/step_up_email_delivery_release_race_test.rb test/operations/identity_step_up_email_delivery_recorder_test.rb test/operations/identity_step_up_email_verification_committer_test.rb test/operations/identity_step_up_email_code_issuer_test.rb test/concurrency/base_step_up_admission_reference_race_test.rb` passed: 20 runs, 114 assertions, 0 failures, 0 errors, 0 skips. The scoped `git diff --check` passed.
- The mail transport was simulated. Production SMTP has open/read timeouts, but the total deadline, a real SMTP outage and a competing database lock timeout were not established. The full suite was not run.
