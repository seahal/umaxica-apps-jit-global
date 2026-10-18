# Browser RP actor writer-role repair

- Commit under test: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`
- Worktree state: uncommitted changes were already present; no unrelated work was reset, staged, or committed.
- Database policy: all commands used the ordinary Rails `test` database with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset. No isolated database or guard bypass was used.

## Finding and fix

The full Rails run exposed a reproducible failure in the COM recovery-secret parallel GET. The RP
session and Device Session were read from the ticket writer, but the delegated `Visitor` association
was preloaded through the GET's outer read role. The test replica did not contain the actor row, so
the Browser RP chain treated an otherwise valid credential as invalid and redirected to `/sign`.
The same request then attempted its safe refresh from the read role and failed closed when the
client-assertion replay record could not be inserted.

`BrowserRpAuthentication` now preloads only the ticket-owned Device Session and resolves the actor
ID through that row. It reloads the actor from the actor model's own `AppZenithRecord`,
`ComZenithRecord`, or `OrgZenithRecord` writer before validating the subject and lifecycle. This
keeps every authentication decision on authoritative writers without changing the surface boundary.

## Verification

Before the change:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/integration/recovery_secret_parallel_get_test.rb
```

failed with **1 run / 0 assertions / 0 failures / 1 error**. The error was a 302 to `/sign` even
though the diagnostic chain showed the RP session, current root, Device Session, subject and expiry
were valid. The request log recorded an actor association missing on the read role and a failed
`security_consumed_jtis` write in read-only mode.

After the change, the same command passed with **1 run / 3 assertions / 0 failures / 0 errors / 0
skips**. The Browser RP regression selection passed **93 runs / 560 assertions / 0 failures / 0
errors / 0 skips**:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/concerns/browser_rp_authentication_test.rb \
  test/controllers/base/com/identity/recovery_secrets_controller_test.rb \
  test/integration/recovery_secret_parallel_get_test.rb \
  test/integration/oidc_rp_browser_flow_test.rb \
  test/services/oidc_access_jwt_child_revoke_independence_test.rb \
  test/controllers/base/com/roots_controller_test.rb \
  test/controllers/warp/com/dashboards_controller_test.rb
```

Static checks passed:

- `bin/rubocop app/controllers/concerns/browser_rp_authentication.rb app/controllers/concerns/authentication_logout_current_session.rb test/operations/sign_out_refresh_race_test.rb` — 3 files, no offenses.
- `ruby -c` for all three Ruby files — syntax OK.
- `git diff --check` for the three changed files — clean.
