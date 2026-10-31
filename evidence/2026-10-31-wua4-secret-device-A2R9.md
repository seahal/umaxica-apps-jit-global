# Secret management device session checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- Before the change, individually injected revoked-device cases could rename, confirm storage, or revoke a Secret with otherwise valid Step-Up. Each now denies the operation before consuming proof.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_name_committer_test.rb` passed: 13 runs, 152 assertions.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_revocation_committer_test.rb` passed: 14 runs, 232 assertions.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_committer_test.rb test/operations/client_secret_storage_confirmation_concurrency_test.rb` passed: 11 runs, 176 assertions. All listed runs had no failures or errors.
- The combined Email preference, TOTP rename, Secret management and Step-Up tests passed after the device checks: `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_email_preference_committer_test.rb test/operations/identity_totp_name_committer_test.rb test/operations/client_secret_name_committer_test.rb test/operations/client_secret_revocation_committer_test.rb test/operations/client_secret_storage_confirmation_committer_test.rb test/operations/client_secret_storage_confirmation_concurrency_test.rb test/integration/step_up_authentication_test.rb`, 79 runs and 755 assertions, with no failures or errors.
- Superseded-but-still-active device tokens also succeeded before the current-token check. Targeted cases for Secret rename and revocation now pass; the full respective files passed with 14 runs/156 assertions and 15 runs/236 assertions. Confirmation and concurrency passed together with 12 runs/181 assertions. All had no failures or errors.
