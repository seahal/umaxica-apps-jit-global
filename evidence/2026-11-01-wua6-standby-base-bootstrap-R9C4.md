# WU-A6 Standby refusal at Base Step-Up bootstrap

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 586 staged, unstaged, or
  untracked status entries before this evidence file was added; no commit was created.
- A public HTTP test with an authenticated Standby ORG browser session and no registered Passkeys
  reproduced a gap: the Base `/verification/setup` GET returned HTTP 200 and rendered the
  first-authenticator bootstrap page. The ordinary Step-Up start GET was already refused.
- `Base::Org::Verification::SetupsController#show` now applies the existing Standby refusal
  immediately after authorization, before scope/target validation, credential lookup, or rendering.
  The test covers the Step-Up start GET, bootstrap GET, and bootstrap POST; each returns the
  existing 403 unavailable response. Step-Up transaction count, Admission Binding count,
  authentication context, and freshness remain unchanged.
- The test compares Normal and Standby with the same valid signed internal return target and
  authenticated RP browser credentials. Normal receives the bootstrap page without creating a
  transaction or binding. Passkeys are removed only from the fixture-free test's transactional test
  context to reach the otherwise-valid bootstrap branch.

## Verification

- Before the controller change, the focused request reproduced the defect: 1 run, 3 assertions, 1
  failure because bootstrap GET returned 200 instead of 403.
- `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb --include '/Standby cannot start Step-Up/'`
  — 1 run, 11 assertions, 0 failures, 0 errors, 0 skips.
- A separate public HTTP test seeds matching fresh `settings_telephone` Step-Up proof on Standby and
  verifies Telephone registration `new` and `create` both return 403 without adding Telephone or
  ceremony rows or changing context/freshness.
- The full affected file passed after both additions: 6 runs, 78 assertions, 0 failures, 0 errors, 0
  skips.
- `bundle exec rubocop app/controllers/base/org/verification/setups_controller.rb test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb`
  — 2 files inspected, no offenses.
- `ruby -c` on both Ruby files — Syntax OK. `git diff --check` on the changed Ruby and documentation
  files passed.
- Updated `docs/security/org-emergency-access.md` to state that Base ORG Step-Up and bootstrap pages
  refuse Standby.

No application schema, migration, development data, production data, or Neon data was changed. These
checks close only the Base bootstrap-page and Telephone-registration-start refusal gaps; real
Standby Root issuance and the full AC-41 per-operation matrix remain open. The full suite was not
run.
