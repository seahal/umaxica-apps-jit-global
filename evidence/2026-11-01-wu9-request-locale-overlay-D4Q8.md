# WU-9 request locale overlay

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had uncommitted changes before this evidence file was added (275 paths reported by
  `git status --short`).
- `PreferenceRequestOverlay` and the current Preference architecture resolve request locale from
  `lx`, then `ri`, then the verified Preference language. APP/ORG localization already preserved
  that precedence. COM hydration replaced its initial request overlay with the JWT snapshot; it now
  reapplies the same request overlay after decoding the verified snapshot.
- Updated the ACME Preference assertions to verify that `ri` changes only the request locale and
  leaves the stored language option unchanged.
- `bin/rails test test/integration/acme_preference_test.rb test/integration/preference_read_symmetry_test.rb test/controllers/base/com/roots_controller_test.rb`
  with local Preference JWT settings and one worker: 138 runs, 1,169 assertions, 0 failures, 0
  errors, 0 skips.
- A read-only query of `test_app_zenith_db` found 0 orphan `enterprise_units` and 0 orphan
  `persona_memberships` by `enterprise_id`. The previously recorded fixture foreign-key error was
  not reproduced by the targeted ACME run. No test database rebuild or repair was performed.
- RuboCop inspected the two modified Ruby files with no offenses. `git diff --check` and `ruby -c`
  for both files passed.
- The WU-9 full-suite baseline comparison remains unverified.
