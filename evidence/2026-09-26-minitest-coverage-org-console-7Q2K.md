# Minitest coverage and ASVS fixes: org Support and IAM console

Commit: `310745dc291913c5b9baaae76738442c4ec9ff1d` (worktree had many uncommitted changes, all
included in the runs).

## Tests added

- `test/controllers/base/org/support/visitors_controller_test.rb`
- `test/controllers/base/org/support/visitor_revocations_test.rb`
- `test/controllers/base/org/support/enforcement_case_pages_test.rb`
- `test/controllers/base/org/support/enforcement_confirmation_screens_test.rb`
- `test/controllers/base/org/iam/grant_pages_test.rb`

## Defects found and fixed (OWASP ASVS V5 input validation, V7 error handling)

- An Enforcement apply whose `identifier_effect` omitted `attachment_blocked` or `recovery_blocked`,
  or whose `principal_effect` sent a blank flag, reached PostgreSQL as NULL and failed with
  `PG::NotNullViolation` (HTTP 500). The effect models now validate those flags as booleans.
- `has_one :principal_effect` did not validate the associated record, so once the flags were
  validated an invalid Principal Effect was dropped silently and the Case still went active. The
  association now uses `validate: true` on all three realms.
- `EnforcementCaseApplyOperation` marked a Case `failed` even when the state transaction rolled
  back. The approval-failure test only passed before because `I18n::MissingTranslationData` (an
  `ArgumentError`) escaped first. The operation now marks `failed` only after the state change
  committed; locale keys for the effect associations were added.

## Results

- `bin/rails test test/controllers/base/org test/operations test/models`: 3716 runs, 0 failures.
- First coverage run (`COVERAGE=true bin/rails test`, before the second batch): 12018 runs,
  0 failures; missed lines 2546 -> 2376, line 96.19%, branch 74.68%, method 91.88%. SimpleCov
  minimums (98 / 93 / 97) were not met before or after.
- Second coverage run after all changes: missed lines 2327, line 96.27%, branch 74.79%, method
  92.02%.

## Third batch (2026-09-27)

Added `test/controllers/base/org/iam/grant_submissions_test.rb`, and new cases in
`test/controllers/auth/org/sign_outs_controller_test.rb` and
`test/controllers/base/app/avatar_ownership_transfers_controller_test.rb`.

`COVERAGE=true bin/rails test`: 12040 runs, 0 failures, 0 errors, 2 skips. Missed lines 2313;
line 96.30%, branch 74.84%, method 92.07%.

Observed dead code: `AuthenticationBase#transparent_refresh_allowed?` always returns `false`, so
`transparent_refresh_access_token` and `attempt_transparent_refresh!` cannot be reached by any test.
