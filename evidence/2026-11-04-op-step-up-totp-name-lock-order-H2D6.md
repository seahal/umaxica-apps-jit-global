# O-10 TOTP rename commit order

- Commit: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; results cover the checked-out worktree.
- Date: 2026-11-04.

## Verification performed

`PARALLEL_WORKERS=1 bin/rails test test/operations/identity_totp_name_committer_test.rb` passed **8
runs / 27 assertions / 0 failures / 0 errors / 0 skips**. It verifies that a root token may be
resolved from the evidence-bound `sid`, Zenith commits before OP transaction release, authorization
refusal does not change the credential, and confirmed Zenith completion remains successful if
releasing the OP transaction fails.

`bundle exec rubocop app/operations/identity_totp_name_committer.rb test/operations/identity_totp_name_committer_test.rb`
passed with no offenses. Scoped `git diff --check` passed for these files.

`PARALLEL_WORKERS=1 bin/rails test test/integration/totp_rename_committed_http_test.rb` completed
with **4 runs / 8 assertions / 4 failures**. The requests redirected to sign-in before reaching the
writer: the test setup has only the legacy OP Access cookie and no RP-local session cookie. This
integration fixture needs migration to the shared-role RP session contract; the failure does not
test the changed operation boundary.

The OP-release-failure path is covered. Lost Zenith commit acknowledgement still has no durable
operation-specific receipt and remains an O-10 gap. The configured test DB catalog was used; no
development or production database was accessed or modified.

## Follow-up: shared-role HTTP fixture migration

The first integration run above used only the legacy Access cookie and failed before the writer
because the RP-local session cookie was absent. The fixture now creates an exact RP-local callback
session and includes its cookie plus the Step-Up event claims. Its teardown removes only the
session, OP-session anchor, identity binding and principal created by that fixture. The updated
command `PARALLEL_WORKERS=1 bin/rails test test/integration/totp_rename_committed_http_test.rb`
passed **4 runs / 25 assertions / 0 failures / 0 errors / 0 skips**. RuboCop across the operation
and both tests passed with no offenses; scoped `git diff --check` passed.
