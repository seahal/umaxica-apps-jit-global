# P3d ceremony and authentication concurrency matrix

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree already contained staged, unstaged and untracked changes; they were preserved.
  No reset, cleanup, commit, push, production or shared-database operation was performed.
- The run used the owned PostgreSQL manifest
  `tmp/acceptance-isolated-20261010p8b-primary.json`, four Rails workers and the 20 listed
  disposable databases.

## Command

```text
bundle exec rails test \
  test/models/ceremony_owned_otp_concurrency_test.rb \
  test/models/auth_email_otp_consumption_concurrency_test.rb \
  test/models/auth_ceremony_session_concurrency_test.rb \
  test/models/auth_ceremony_revocation_concurrency_test.rb \
  test/consumers/totp_window_consumer_concurrency_test.rb \
  test/operations/telephone_sign_up_otp_issuer_test.rb \
  test/operations/contact_registration_otp_verification_committer_test.rb
```

## Result

`118 runs, 1653 assertions, 0 failures, 0 errors, 0 skips` in `5.909` seconds.

The collection exercised independent-connection one-time Email/Telephone ceremony consumption,
authentication Email consumption, session/revocation concurrency, TOTP window consumption,
Telephone sign-up issuer retry/consumption and registration OTP verification. The collection did
not use external providers, production data or a distributed transaction. A read-only Rails
catalog follow-up reported `manifest_databases=20`, `worker_db_count=0` and
`active_worker_sessions=0`.

This is current focused concurrency evidence for the selected P3d cells. It does not close every
purpose/realm/provider applicability cell, the full cross-database transport fault campaign, or
the remaining source/fixture/constraint retirement inventory. No application or schema source
changed in this slice, so the latest full Rails/Vitest Gate remains the applicable shared-worktree
gate.
