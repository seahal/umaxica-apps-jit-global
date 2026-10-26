# WU-24h: retired legacy Base social-completion readers

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree had broad uncommitted changes from this cycle; only the two files below
were changed by this work.

## Finding

`evidence/2026-10-24-wu24h-binding-ownership-H8P2.md` left open the new-FK agreement of the
legacy Base social-completion readers. A search of `app/` and `lib/` found no production caller of
`BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!` or
`.validate_completed_social_signup_browser_binding!`; their callers were removed with the Base
social completion route in WU-05g (`evidence/2026-10-24-wu05dg-social-sign-up-in-auth-W5DG.md`).
The open point therefore has no runtime subject.

## Change

- Removed both methods and the private helpers used only by them
  (`validate_completed_social_parent!`, `completed_social_authorization_parent_valid?`,
  `completed_social_sign_in_parent_valid?`, `completed_social_sign_in_parent_pending?`) from
  `app/services/base_auth_admission_coordinator.rb`.
- Removed the one test whose subject was the removed method
  (`test/services/base_auth_admission_coordinator_test.rb`, "social signup acceptance requires the
  redeemed browser parent and exact provider evidence").
- Shared helpers they used (`validate_sign_in_path_curfew!`, `ensure_binding_browser_matches!`,
  `ensure_binding_token_matches!`, `validate_admission_parent!`, `validate_admission_root!`,
  `admitted_ceremony_session`, `result_root_context_matches?`) still have other callers and stay.

## Verification

- `bin/rails test test/services/base_auth_admission_coordinator_test.rb`: 21 runs, 135 assertions,
  0 failures, 0 errors.
- `bundle exec rubocop` on both files: no offenses.
- Full suite not run (other tasks were using the test database).
