# Base Step-Up admission parent lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code tested here.
- The admission issuer previously locked the pending session before its referenced parent. The focused issuer file passed before the change: 16 runs, 267 assertions.
- The issuer now reads the reference, locks the referenced parent, locks the session and rejects a changed reference. `PARALLEL_WORKERS=1 bin/rails test test/operations/base_step_up_admission_issuer_test.rb test/controllers/auth/step_up_admission_test.rb test/concurrency/step_up_email_lock_order_test.rb` passed: 25 runs, 407 assertions, 0 failures, 0 errors, 0 skips.
- The independent Email test in this group does not exercise a concurrent admission session replacement. Other paths and the full suite remain unverified.
