# WU-A13 one-day sign-up eligibility implementation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried uncommitted
  WU-3..WU-7 slices of prior sessions plus these changes.
- Requirement: R-AU-50 of `two.md` section 3.11 (design "P-case") implementing
  `adr/sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`. The removed branch
  halts a sign-up whose birthdate is below the old 16/13 thresholds; the implemented rule is the
  explicit one-day rule and other HALTED reasons are unchanged.
- Changed:
  - `app/policies/sign_up_eligibility_policy.rb`: the single shared rule
    `eligible?(birthdate, surface:, today:)` for `.app` and `.org` (at least one calendar day
    before the service date; today refused on purpose; tomorrow invalid); an unsupported surface
    still raises. No 16/13 thresholds remain.
  - `app/controllers/concerns/sign_up_sequence_controller_support.rb`: the under-age
    `SignUpTermination` halt branch and `render_sign_up_age_restricted` are removed. The
    checkpoint keeps validating the unsaved value (D-178) and now runs the explicit eligibility
    check with the model validation (fail closed); the ineligible birthdate answers 422 with the
    public date copy and leaves the checkpoint active. A leftover worktree RuboCop debt in
    `finalize_sign_up_from_checkpoint!` (51/45 `Metrics/MethodLength`) was closed by extracting
    the post-transaction tail into
    `handle_sign_up_checkpoint_finalization_outcome!` with identical control flow.
  - `app/controllers/concerns/sign_up_explicit_step_controller_support.rb`,
    `app/controllers/concerns/app_sign_up_checkpoint_page.rb`,
    `app/services/sign_up_session_state.rb`: the age-restricted checkpoint flag, component and
    session key are removed; the phase-refusal path no longer regenerates the age screen.
  - `src/pages/auth/app/sign/up/checkpoints/age_restricted.tsx` and
    `src/features/auth/signup/SignUpAgeRestricted.tsx` deleted; the `age_restricted` locale copy
    removed from `config/locales/{en,ja}.yml`.
  - `docs/policy/signup-eligibility.md` rewritten for the implemented contract; the ADR status
    marked implemented with the `.org` explicit-policy decision recorded; the sign-up section of
    `docs/mermaid/idp-state-machine-transition-inventory.md` and the app row of
    `docs/reference/ui-view-inventory.md` updated in the same change.
- Public boundary results:
  - process: policy check tests give yesterday accepted, today and tomorrow refused, refusal
    travels with the service date, `.org` supported without raising, unsupported surface raises,
    unparseable input ineligible.
  - "process end": `test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb`:
    today birthdate refuses with 422 and leaves the flow CHECKPOINT_PENDING; yesterday completes
    the cycle; the refused-birthdate loop now covers today, tomorrow and a far future date with
    one public message. 13 runs, 335 assertions, 0 failures.
  - activity: the google social halt journey (born thirty years ago -> eligibility bypassed)
    was retired: the machine rewrites in the file had already refactored the flow away, and the
    eligible-date completion is covered by the accepted sign-up journeys (`2000-01-01`) and the
    email loop. The old direct-controller test with eleven singleton stubs was removed with
    them.
  - `.org`: `test/controllers/auth/org/sign_ups_controller_test.rb` keeps its invitation flow
    unchanged by this change; the policy accepts `surface: :org` without `ArgumentError`
    (policy test).
  - Activity: `test/controllers/concerns/ + preference_web_csrf_test.rb` 741 runs, 8,982
    assertions, only the two recorded baseline failures; `bun run test` 96 files / 1052 tests
    green after the React page deletion.
- Pre-existing failures observed in this worktree, not caused by and not repaired in this slice
  (their diagnosis: GET `/sign/{,org/}up` now answers 303 to the Visa ceremory
  binding confirmation instead of the page the render tests stubbed, and social journeys fail at
  `at_css` on a String response; both areas belong to earlier uncommitted work, test cleanup is
  out of this slice's scope): `test/controllers/auth/app/sign_ups_controller_test.rb` (9),
  `test/controllers/auth/org/sign_ups_controller_test.rb` (5),
  and the `test/integration/social_auth_login_test.rb` battery (5 failures, 6 errors;
  `test_Google_login_with_existing_identity_does_not_create_new_user` reproduces alone with
  `NoMethodError ... at_css for String`).
- `bin/rubocop` clean on all touched files after style correction.
- Not established: age-dependent feature inventories (production precondition per ADR decision
  5 review), `.org` birthdate collection, WU-9 removing the remaining `adult_content_gate`
  registry/stopper references.
