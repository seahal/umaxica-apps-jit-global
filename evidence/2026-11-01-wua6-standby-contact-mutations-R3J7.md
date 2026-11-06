# WU-A6 ORG contact mutation comparison

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 580 staged, unstaged or
  untracked paths before this evidence file was added; no commit was created.
- A fixture-free HTTP case exercised owned Email preference update and Telephone removal under
  Normal with fresh matching Step-Up state; both succeeded. The same endpoints under Standby
  returned 403, leaving the Email values, target Email and Telephone records unchanged and retaining
  the Standby context and Step-Up timestamp. It also opened the ORG withdrawal information page
  under Normal and received the explicit Step-Up-unavailable 403 under Standby with matching fresh
  Step-Up state.
- The focused contact/lifecycle case passed (1 run, 19 assertions). The complete fixture-free
  Standby operation file passed: 4 runs, 64 assertions, 0 failures, 0 errors, 0 skips. Scoped
  RuboCop, `ruby -c`, and `git diff --check` passed. The focused contact case initially returned 422
  when sent through a separate browser test session; using the shared integration-test session and
  its request protections passed.
- Test command:
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb`.
  The first host-shell boot lacked the COM Preference issuer and stopped before test execution; this
  rerun supplied the checked-in local issuer values.
- No production behavior, schema, production database or Neon data changed. This remains
  seeded-session evidence for the contact operations and ORG withdrawal page, not actual Standby
  Root issuance or the full AC-41 policy-derived matrix. The full suite was not run.
