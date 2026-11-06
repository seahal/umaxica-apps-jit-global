# WU-A6 ORG Standby Secret credential mutation refusals

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty (568 staged, unstaged, or
  untracked status entries at verification); no commit was created.
- `test/controllers/base/org/identity/removals_controller_test.rb` now verifies separate
  Standby-session requests for Secret update and removal. Each returns 403 and leaves the credential
  active; the update also preserves its name. Both preserve Standby context, leave Step-Up freshness
  absent, and create no `OperatorStepUpCeremonyTransaction`.
- The test class seeds its own Operator/references and disables global fixtures. Global fixtures
  previously failed before the test body on missing Chronicle event IDs 9 and then a missing Bureau
  Operator FK; `operator_chronicle_events.yml` now declares fixed event IDs 8–10 for the Secret
  events, and the self-seeding class avoids the unrelated global fixture graph.
- An initial test invocation could not boot because this shell lacked the required
  `PREFERENCE_COM_JWT_ISSUER`, `PREFERENCE_COM_JWT_AUDIENCE`, and `PREFERENCE_COM_JWT_REVOKED_KIDS`
  entries. The successful runs passed those required values from the tracked Dev Container contract
  explicitly; no application fallback was added.
- A combined two-request attempt returned 403 for update and redirected the subsequent removal
  request to sign-in (302) when the same handcrafted request headers were reused. A separate
  `open_session` attempt failed route recognition before reaching the action. The final tests
  exercise each action using its own generated session and existing IntegrationTest request harness;
  same-browser sequential persistence after a refusal remains unverified.
- This is partial AC-41 evidence. Secret enrollment, the full Normal/Standby operation matrix, and
  Standby Root issuance remain open. No production or Neon operation was performed.

## Follow-up: edit page

The existing Standby update case now also requests the Secret credential edit page before submitting
the update. Both the edit GET and update PATCH return 403, and the credential remains unchanged. The
focused case passed again (1 run, 7 assertions); scoped RuboCop and Ruby syntax passed, and
`git diff --check` passed for the test file. This verifies the edit-page gate for the same seeded
Standby session; it does not close the wider AC-41 matrix.

The entire affected controller file then passed (7 runs, 30 assertions, 0 failures, 0 errors, 0
skips). This follow-up was performed against HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` with
587 staged, unstaged, or untracked worktree paths; the worktree remains uncommitted.

## Verification

- `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/controllers/base/org/identity/removals_controller_test.rb --include /Standby/`
  — 2 runs, 12 assertions, 0 failures, 0 errors, 0 skips.
- `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/controllers/base/org/identity/removals_controller_test.rb`
  — 7 runs, 29 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/controllers/base/org/identity/removals_controller_test.rb` — 1 file
  inspected, no offenses.
- `ruby -c test/controllers/base/org/identity/removals_controller_test.rb` — Syntax OK.
- `git diff --check -- test/controllers/base/org/identity/removals_controller_test.rb test/fixtures/operator_chronicle_events.yml`
  — passed.

Tests used only local test databases. No application code, schema, or migration was changed in this
slice; production and Neon were untouched.
