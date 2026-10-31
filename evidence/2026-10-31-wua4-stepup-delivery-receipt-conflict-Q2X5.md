# Email Step-Up delivery receipt conflict

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the tested code.
- Two focused cases found that valid current Email Step-Up codes with pending or failed delivery state are refused (2 runs, 2 assertions, 2 failures against the proposed behavior).
- Temporarily removing the two application delivery-state checks led to three errors in the related group; PostgreSQL rejected consumption with `client_step_up_email_generation_valid`. The migration `db/op_base_app_migrate/20261003202100_bind_client_step_up_email_challenge.rb` requires delivered status when consumed. The incomplete implementation and its temporary tests were reverted; the current state diagram's delivery-lock comment was corrected to match the preceding delivery change.
- After reverting the incomplete behavior, `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_step_up_email_verification_committer_test.rb test/operations/identity_step_up_email_delivery_recorder_test.rb test/operations/identity_step_up_email_code_issuer_test.rb test/concurrency/step_up_email_delivery_release_race_test.rb test/concurrency/step_up_email_lock_order_test.rb` passed: 20 runs, 114 assertions, 0 failures, 0 errors, 0 skips.
- Whether two.md §12.2 includes this Step-Up-specific code path requires scope review. A constraint and behavior change needs explicit shape review; no schema change or migration was performed. The full suite was not run.
