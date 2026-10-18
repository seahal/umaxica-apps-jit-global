# Coverage Batch 18

Date: 2026-07-04 20:19:39 UTC

## Summary

This batch stayed test-only and focused on two low-risk coverage gaps:

- `test/services/sign_up_artifact_cleanup_test.rb`
- `test/services/step_up/available_methods_test.rb`

The Rails suite still has a pre-existing OIDC RP browser-flow failure in the full coverage run, but
the batch completed the required narrow validation and produced a new full-suite coverage snapshot.

## Coverage Snapshot

- Starting Rails coverage: 90.49% line coverage, 69.06% branch coverage.
- Ending Rails coverage: 90.65% line coverage, 69.48% branch coverage.
- Starting VP coverage: not measured in the previous batch.
- Ending VP coverage: 0% lines, 0% statements, 0% branches, 0% functions because
  `vp test --coverage` reported no test files.

## Failures / Errors

- Starting failures / errors: 1 failure, 0 errors in the previous documented full coverage attempt.
- Ending failures / errors: 1 failure, 0 errors in `COVERAGE=true bin/rails test test/`.
- The ending full-suite failure was
  `OidcRpBrowserFlowTest#test_app_email_sign-in_session-limit_handoff_signs_in_Sign_and_leaves_capacity_for_RP_callback_session`.

## Selected Targets

1. `StepUpCooldowns.key`
2. `StepUpCooldowns.active_methods`
3. `SignUpArtifactCleanup.cleanup_pending_for`
4. `SignUpArtifactCleanup#call` rescue path
5. `SignUpArtifactCleanup#schedule_dependent_retention!` fallback attrs path
6. `SignUpArtifactCleanup` client telephone cleanup path
7. `SignUpArtifactCleanup` visitor telephone cleanup path
8. `SignUpArtifactCleanup#client_pending_contact?` false branch
9. `SignUpArtifactCleanup#visitor_pending_contact?` false branch

## Tests Added

- `test/services/step_up/available_methods_test.rb`
  - added coverage for `StepUpCooldowns.key`
  - added coverage for `StepUpCooldowns.active_methods`
- `test/services/sign_up_artifact_cleanup_test.rb`
  - added a fake worker-claim test for `cleanup_pending_for`
  - added a rescue-path test for cleanup failure
  - added a fallback-retention test for non-Retainable dependent records
  - added client telephone and visitor telephone cleanup tests
  - added false-branch tests for `client_pending_contact?` and `visitor_pending_contact?`

## App / DB Changes

- None. This batch changed `test/**` only.

## Dead-Code Evidence

- None. No code deletion was attempted.

## Commands Run

- `bin/rails test test/services/sign_up_artifact_cleanup_test.rb`
- `bin/rails test test/services/step_up/available_methods_test.rb`
- `bin/rails test test/services/sign_up_artifact_cleanup_test.rb test/services/step_up/available_methods_test.rb`
- `vp check --fix`
- `bundle exec rubocop -a test/services/sign_up_artifact_cleanup_test.rb test/services/step_up/available_methods_test.rb`
- `COVERAGE=true bin/rails test test/`
- `vp test --coverage`

## Skipped Risky Areas

- `config/**`, `bin/**`, routes, fixtures, factories, CI files, and dependency files were left
  untouched.
- Auth/session/OIDC/logout/refresh/token/credential/security flows were not modified.
- The VP checker still reports pre-existing TypeScript project issues in
  `src/entrypoints/inertia.tsx` and `@styles/application.css`, but those files are outside the
  allowed edit scope for this batch.

## Next Batch Candidates

- Continue with the remaining safe, deterministic `test/**` targets exposed by the Rails coverage
  report.
- Revisit `app/services/sign_up_artifact_cleanup.rb` only if there is a clearly safe branch left to
  cover with a small, deterministic test.
- Re-run the Rails coverage report before selecting the next batch so the next target list is based
  on current data.
