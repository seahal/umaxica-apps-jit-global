# Full reauthentication parent lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- Inspection found full reauthentication finalization locking the Step-Up session before the parent transaction. The focused freshness file passed before reordering: 21 runs, 142 assertions.
- After reordering, `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_step_up_ceremony_freshness_committer_test.rb test/operations/identity_step_up_ceremony_cancellation_committer_test.rb test/concurrency/step_up_email_lock_order_test.rb` passed: 29 runs, 190 assertions, 0 failures, 0 errors, 0 skips.
- The independent race covers Email delivery, not full reauthentication. `BaseStepUpAdmissionIssuer` still locks a session before the referenced parent. The full suite was not run.
