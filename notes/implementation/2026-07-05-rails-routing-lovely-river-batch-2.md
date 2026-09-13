# Rails Routing Lovely River Batch 2

Date/time: 2026-07-05T15:55Z

## Coverage

- Starting Rails coverage: not separately re-measured in this batch; the pre-existing report was
  treated as stale and the batch used a fresh end-of-batch coverage run.
- Ending Rails coverage: 90.74% line coverage, 69.56% branch coverage.
- Starting VP coverage: unknown; `vp test --coverage` reports no matching test files.
- Ending VP coverage: unknown; `vp test --coverage` exited with code 1 and reported 0/0 coverage
  because no VP test files were found.

## Selected Targets

- Rename `auth` sign-entry route resources from legacy verb-ish names to noun resources while
  preserving URL paths and helper names.
- Rename `base` sign-out route resources from legacy verb-ish names to a noun resource while
  preserving URL paths and helper names.
- Update route-source guard tests to assert the new route vocabulary and reject the old source
  forms.

## Tests Added or Updated

- Updated `test/controllers/auth/route_naming_test.rb`.
- Updated `test/unit/security/identity_authority_inversion_guard_test.rb`.

## App/DB Changes

- Updated `config/routes/auth.rb`.
- Updated `config/routes/base.rb`.
- No database changes.

## Dead-Code Evidence

- None. This batch did not delete code; it only renamed route resources and kept the external paths
  and helpers stable.

## Commands Run

- `bin/rails test test/controllers/auth/route_naming_test.rb test/integration/routes/auth_sign_ceremony_route_contract_test.rb test/integration/routes/base_authority_route_contract_test.rb test/unit/security/identity_authority_inversion_guard_test.rb`
- `bin/rails test test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb`
- `vp check --fix`
- `bundle exec rubocop -a`
- `COVERAGE=true bin/rails test test/`
- `vp test --coverage`

## Failures and Errors

- `vp check --fix` reported existing TypeScript issues in `src/entrypoints/inertia.ts` and
  `src/entrypoints/inertia.tsx`:
  - TS6307: file not listed in `tsconfig.app.json`
  - TS2882: missing module or type declarations for `@styles/application.css`
- `bundle exec rubocop -a` reported many pre-existing offenses across the repo and auto-corrected 47
  offenses, including formatting in the touched route and test files.
- `COVERAGE=true bin/rails test test/` completed with 8,984 runs, 42,550 assertions, 3 failures, and
  5 errors.
- The full Rails coverage run surfaced existing failures in:
  - `Base::App::Social::AuthenticationsControllerTest`
  - `AuthCredentialTimingProtectionContractTest`
  - `MinimumResponseBudgetTest`
  - `Security::AuthenticationModeInventoryTest`
- `vp test --coverage` found no test files and exited with code 1.

## Skipped Risky Areas

- No changes to auth/token/OIDC logic outside the route definitions.
- No config changes outside allowed route files.
- No fixture, factory, CI, dependency, or database changes.
- No dead-code deletion because no deletion was proven safe in this batch.

## Next Batch Candidates

- Resolve the existing Rails baseline failures around social authentication, minimum response
  budgets, and auth mode inventory.
- Investigate whether VP has tests in a different directory or whether the repo intentionally has no
  matching VP test files.
- Continue route vocabulary cleanup only where helper names and controller namespaces can remain
  stable.
