# Sign-out and RP refresh lock-order verification

- Commit under test: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`
- Worktree state: uncommitted changes were present before and during this check; no unrelated work was reset or staged.
- Database policy: all commands used the ordinary Rails `test` database with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset. No isolated or disposable database was created, and no ownership guard was bypassed.

## Finding and fix

The new independent-connection race test first reproduced PostgreSQL `PG::TRDeadlockDetected`. The sign-out path inserted `ClientSignOutFlow` with a foreign key to the root token before taking the `Device Session -> root -> RP Session` locks. A concurrent RP refresh took the device lock first and then waited for the token lock, while the sign-out transaction held the token foreign-key key-share lock and waited for the device lock.

Persisted tokens now acquire and revoke the parent hierarchy before inserting `ClientSignOutFlow`; the flow is still written inside the same transaction and rolls back with the revocation on failure. The existing in-memory-token edge case keeps its prior persistence-before-revoke behavior.

## Verification

The red run was:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/operations/sign_out_refresh_race_test.rb
```

It failed with `ActiveRecord::Deadlocked` / `PG::TRDeadlockDetected` while locking `client_tokens`.

After the change, the same command passed with **1 run / 10 assertions / 0 failures / 0 errors / 0 skips**. The focused regression set passed with **64 runs / 310 assertions / 0 failures / 0 errors / 0 skips**:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/concerns/authentication/logout_current_session_test.rb \
  test/operations/sign_out_refresh_race_test.rb \
  test/operations/rp_session_revoker_test.rb \
  test/services/oidc_refresh_token_issuer_surface_test.rb \
  test/services/oidc_refresh_token_coalescing_test.rb
```

The sign-out integration set passed with **83 runs / 659 assertions / 0 failures / 0 errors / 0 skips**, covering Identity revocation, Base OIDC logout, end-session validation, authority-first logout, Tech completion, route contracts, Core BFF, Base authority/cache policy, and the race test.

Static checks passed:

- `bin/rubocop app/controllers/concerns/authentication_logout_current_session.rb test/operations/sign_out_refresh_race_test.rb` — 2 files, no offenses.
- `ruby -c` for both Ruby files — syntax OK.
- `git diff --check` for both changed files — clean.
