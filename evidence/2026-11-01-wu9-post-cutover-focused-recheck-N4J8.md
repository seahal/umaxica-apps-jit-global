# WU-9 post-cutover focused recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained uncommitted changes; no commit was created.
- Ran `test/models/targeted_model_line_coverage_test.rb:139` with local Preference COM issuer
  settings, a Valkey run ID and one worker: 1 run, 4 assertions, 0 failures, 0 errors, 0 skips. The
  earlier fixture-load foreign-key error for this test was not reproduced after the recorded
  `test_app_zenith_db` rebuild.
- Ran lines 84 and 121 of `test/integration/oidc_initiated_sign_in_completion_test.rb` with local
  Preference COM issuer settings, a Valkey run ID and one worker: 2 runs, 30 assertions, 0 failures,
  0 errors, 0 skips. These exercise explicit-only Visa Preference reflection and preservation of a
  completed sign-in when Preference signing fails.
- Corrected `docs/architecture/current_context.md`, `docs/architecture/controller-lifecycle.md`, and
  `docs/architecture/preference.md` where they described the retired Preference refresh or
  overstated GET database/cookie behavior. A scoped `git diff --check` over these docs and the JWT
  changes passed.
- The first `preference_read_symmetry_test.rb` plus `warp/com/roots_controller_test.rb` run had 2
  failures in the latter file: assertions expected `language=en` while the request explicitly
  supplied `ri=jp`. The implementation overlays the explicit region to Japanese. Updated the stale
  test expectations and the current-context overlay description.
- Re-ran those two test files with local Preference COM issuer settings, a Valkey run ID and one
  worker: 16 runs, 146 assertions, 0 failures, 0 errors, 0 skips. RuboCop on
  `test/controllers/warp/com/roots_controller_test.rb` reported no offenses; scoped
  `git diff --check` passed.
- The full suite was not rerun. The earlier full-suite comparison predates the database rebuild and
  these focused checks; this evidence does not establish full WU-9 acceptance or classify remaining
  suite failures.
