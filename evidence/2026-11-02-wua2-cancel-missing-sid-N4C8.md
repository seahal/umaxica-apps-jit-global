# WU-A2 Cancel replay without the Auth SID

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- Before this record was added, the worktree had 550 changed tracked paths and 270 untracked paths;
  no staged changes. Existing work was preserved and no commit was created.
- Extended the APP and ORG public Cancel journeys to check a retry after the Auth SID has been
  removed. The request receives 409 with no Location, Auth SID cookie write, or DBSC header; the
  canceled parent, binding and ceremony remain unchanged. The existing exact-old-SID retry path
  still succeeds.
- The APP integration class no longer loads the `clients` fixture: its only fixture actor use was
  replaced with an actor created in that test. This allowed the tests to run despite a pre-existing
  orphan `client_telephones.user_id` row that caused fixture loading to fail before the test body.
  The orphan row was not modified.
- The first added assertion run failed because the test captured its cookie snapshot before removing
  the empty SID entry from the local CookieJar. The snapshot was moved after that test-side removal
  and the check was rerun.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/sign_entry_exit_flow_test.rb test/integration/sign_entry_exit_org_flow_test.rb`:
  15 runs, 284 assertions, 0 failures, 0 errors, 0 skips.
- Final focused APP/ORG cases: 2 runs, 67 assertions, 0 failures, 0 errors, 0 skips. RuboCop on both
  files reported no offenses; Ruby syntax and `git diff --check` passed.
- The full suite was not run. This slice does not close WU-A2 or `two.md`; other cancellation,
  registration-completion and race acceptance remains open.
