# WU-A14 suspended-notice dead branch removal (partial WU-A14)

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried the uncommitted
  WU-3..WU-7, WU-A1, WU-A13 and WU-A6 slices of this cycle plus these changes.
- Classification for the `two.md` §3.11 WU-A14 row: the `suspended_notice` prop never carries a
  value. The FeatureFlags registry has no `sign_in_suspended_*` or `sign_up_suspended_*`
  kill switch; availability lives in the four `*_available_{app,org}` sentry flags whose BLOCKED
  path answers with the uniform sentry refusal before any entry page renders. Both app and org
  controllers hardwired `suspended_notice: nil`. The React branch therefore described a mechanism
  that no longer exists and was removed as dead UI (not a blanket ENV sweep; the remaining
  WU-A14 items - BL-19/22/23, R-AU-46 attribute copy - are still individually unclassified).
- Removed the prop, its interface, the alert branch and the `sign-up-suspended` test id from
  `SignUpMethodChoice`, `AuthMethodChoice`, `OrgSignUpEntry`, the org sign-up page props, and
  both Rails prop builders (`app/controllers/concerns/app_sign_up_entry_page.rb`,
  `app/controllers/auth/org/sign/ups_controller.rb`). The gait suspension-screen tests were
  removed and a negative assertion keeps the branch from returning; the e2e ceremony fixture
  dropped the prop.
- Results:
  - `bun run test`: 96 files, 1,050 tests, 0 failures (two fewer tests from the removed
    suspension assertions; all other suites unchanged).
  - `bun x oxlint` on all seven touched JavaScript/JSX files: 0 findings. The five
    `unicorn(prefer-type-error)` errors reported by the full `bun run check` sit in files
    identical to HEAD (`gait/support/stimulus.ts`, `gait/support/dom.ts`,
    `e2e/ui-ceremony-presentation.spec.ts`, `e2e/ui-foundations.spec.ts`) and are pre-existing.
  - `bin/rails test test/controllers/auth/app/sign_ups_controller_test.rb`: 13 runs, 9 failures
    - the same nine 303-to-ceremony-binding render failures observed earlier this cycle before
    this removal, diagnosed in
    `evidence/2026-10-30-wu-a13-one-day-signup-eligibility-M3T7.md` as prior-session behavior;
    `test/controllers/auth/org/sign_ups_controller_test.rb`: 10 runs, the same five pre-existing
    failures. No new failure appeared from this removal.
  - RuboCop clean on the two touched Ruby files.
- Not covered here: BL-19 candidate classification, BL-22/23 disposition, and the R-AU-46
  attribute-copy translations, which still need their own per-item review; the full-suite Rails
  grouping failures listed above are tracked as prior-session needle work (X2/BL-18).
