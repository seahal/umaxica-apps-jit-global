# WU-9 APP/ORG preference retention

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained uncommitted changes before this evidence file was added (273 paths reported
  by `git status --short`).
- Extended `PreferenceLifecycleJob` purging to APP and ORG. Purge checks the owner database expiry
  under the parent row lock, removes dependent children with the parent in one owner transaction,
  and coordinates Chronicle reference checks with shared writer and exclusive purge advisory locks.
- APP, ORG, and COM chronicle subject associations now match on both subject type and id and
  restrict parent deletion. APP/ORG audit writers validate new and changed subject/actor references
  while holding the shared lock. Different subject types may reuse a numeric id without being
  deleted with the Preference row.
- `bin/rails test test/jobs/preference_lifecycle_job_test.rb`: 14 runs, 88 assertions, 0 failures, 0
  errors, 0 skips.
- `bin/rails test test/models/app_preference_test.rb test/models/org_preference_test.rb test/models/com_preference_test.rb`:
  63 runs, 185 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the six modified Ruby files and the lifecycle job test: 7 files inspected, no offenses.
  `git diff --check` passed.
- Intermediate focused runs exposed a test timestamp issue and a mismatch between typed Chronicle
  references and parent associations; those were corrected before the final passing runs above.
- The WU-9 full-suite comparison and broader acceptance matrix remain unverified in this slice.
