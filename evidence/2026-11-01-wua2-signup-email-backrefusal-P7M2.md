# APP sign-up Email Back refusal

Date: 2026-11-01 HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` Worktree: had uncommitted changes
across the repository before and after this check. No commit was created and no existing changes
were reverted.

## Change

The APP sign-up Email `new` action now refuses entry with the shared phase-violation response when
an admitted sign-up flow has already progressed. The guard runs after admission validation and
before the email-flow enforcement callback can reset entry state. A request test checks the refusal
response and unchanged flow and ceremony. A Rails browser journey issues an Email OTP, navigates
Back to the prior entry page, verifies the refusal response and absence of authentication or DBSC
response state, navigates Forward to the OTP page, and uses the explicit Cancel action.

## Checks performed

- `bundle exec bin/rails test test/controllers/auth/app/up/emails_controller_test.rb:339`: 1 run, 14
  assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec bin/rails test test/controllers/auth/app/in/secrets_controller_test.rb:162`: 1 run,
  18 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec bin/rails test test/security/invariants/auth_phase_refusal_response_writer_invariant_test.rb`,
  with the configured local test environment: 1 run, 3 assertions, 0 failures, 0 errors, 0 skips.
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium bun run test:e2e:rails -- e2e/rails/auth-phase-history.spec.ts`,
  with the configured local test environment: 1 browser test passed. It exercised real APP sign-up
  Email OTP issuance and Back/Forward/Cancel navigation.
- Oxfmt check on the changed E2E/config files passed; Oxlint on the E2E/config files passed.
- Ruby syntax checks for the changed controller, two controller test files, and E2E server passed.
- RuboCop on the changed controller and two controller test files: 3 files inspected, no offenses.
- `git diff --check` passed.

The invariant test initially could not load from an incorrect path, then its correct path required
the local environment configuration because JWT registry initialization needs the configured issuer.
Rerunning with the correct path and environment passed.

## Not run or not established

- The full `bin/rails test` suite was not run; it remains reserved for WU closure.
- This slice does not close WU-A2 or WU-A3. The App registration-completion receipt shape review and
  social callback generation shape review remain pending owner decisions; other WU-A2/A3 acceptance
  work is also outstanding.
- The Rails browser test creates local test records. It follows the application Cancel route but
  does not perform broad database cleanup.
