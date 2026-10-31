# WU-4 withdrawal, notification and retention test progress

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including corporate authentication model removal and the test changes below.
- `PARALLEL_WORKERS=1 bin/rails test test/models/step_up_transaction_reference_uniqueness_test.rb`: 6 runs, 38 assertions, no failures, errors, or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/models/withdrawal_flow_test.rb test/models/telephone_credential_registration_otp_receipt_test.rb`: 12 runs, 72 assertions, no failures, errors, or skips. Withdrawal termination and failed timestamp cases were moved to the surviving client model.
- `PARALLEL_WORKERS=1 bin/rails test test/notifiers/notify/otp_notifiers_test.rb`: 9 runs, 34 assertions, no failures, errors, or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/dead_identifier_purge_test.rb`: 18 runs, 89 assertions, no failures, errors, or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/email_sign_up_candidate_creator_test.rb`: 2 runs, 19 assertions, no failures, errors, or skips.
- `bin/rails test` stopped while loading `test/operations/identity_passkey_name_committer_test.rb`, which references the deleted `Visitor` model. The complete suite did not execute.
- Rails test database preparation was used; no production persistence operation or external write was performed.
