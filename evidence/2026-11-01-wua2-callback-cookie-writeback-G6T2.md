# WU-A2 stale social callback cookie write-back

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 484 changed or untracked paths
before this evidence record was added, with no staged changes. Existing work was preserved.

A regression test restored a signed-cookie snapshot from before a social sign-up restart and
submitted its already-consumed callback while retaining the newer cookie in the browser jar. Before
the fix, the refusal response changed that jar's session cookie. The callback guard now identifies a
known consumed state as superseded and skips session persistence for that refusal. Unknown states
continue through the existing cleanup path. The regression test confirms the response leaves the
newer cookie unchanged and the replacement state remains usable.

Verification, with `.env.container.devcontainer` loaded:

- `bin/rails test test/integration/social_login_admission_test.rb`: 18 runs, 403 assertions, 0
  failures, 0 errors, 0 skips.
- `bin/rails test test/integration/social_callback_guard_test.rb`: 12 runs, 93 assertions, 0
  failures, 0 errors, 0 skips.
- `bundle exec rubocop app/controllers/concerns/social_callback_guard.rb test/integration/social_login_admission_test.rb`:
  no offenses.
- `ruby -c` on the changed controller concern and integration test: both syntax checks passed.
- `git diff --check`: passed.
- A combined run including `test/integration/social_callback_refusal_matrix_test.rb` reported its
  existing `SocialCallbackRefusalMatrixTest#test_A07-1e/A08/A34-2` failure (13 runs, 404 assertions
  total). That exact test ID appears in `plans/2026-10-28-baseline-failing-tests.md`; this session
  did not isolate its cause. The standalone callback-guard file passed.

The full suite was not run. Concurrent provider starts from separate stale signed-cookie snapshots
still lack a persisted Admission-generation association; their ordering is unverified and remains
subject to the separate storage-shape approval proposal.
