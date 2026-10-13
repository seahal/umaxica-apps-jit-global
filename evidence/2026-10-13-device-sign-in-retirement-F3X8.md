# Device Sign-in Mock Retirement Verification

Revision: `c93d6529a83b7c09a3a40f534b052bb9290085bd` (full `git rev-parse HEAD`). The worktree had
uncommitted Step 3 implementation and test changes that affected all results below. Frozen plan
hashes remained unchanged.

## Results

- Test-first route/chooser run: 27 tests, 331 assertions, three expected failures while the old
  route and selection entry remained. Its wrapper cleanup initially failed because the cleanup
  script did not load Active Support's `Array#index_with` extension.
- After implementation, `test/controllers/auth/route_naming_test.rb` and
  `test/controllers/auth/app/sign_ins_controller_test.rb`: 27 tests, 337 assertions, zero failures,
  errors or skips.
- Existing Auth App and organization emergency Passkey regression files (14 files listed in the
  command below): 153 tests, 1,212 assertions, zero failures, errors or skips.
- `bun run test -- gait/features/auth/signin/signin_screens.test.tsx`: one file, 19 tests passed.
- Targeted RuboCop on four changed Ruby files: no offenses.
- YAML syntax parsing with `YAML.parse_file` passed for all four changed locale bundles.
- The pre-commit Oxfmt hook reflowed several existing long scalars in the Japanese locale bundles. A
  post-commit data comparison at `499c80d608dbac4c8e080d6b06516921db91f910` confirmed all locale
  values still match the parent revision after removing only the two retired mock keys.
- `git diff --check` passed. The final scoped Valkey cleanup reported zero matching keys deleted and
  verified four run-specific prefixes empty.
- The E2E assertion was updated but Playwright was not run: required E2E runner and service URL
  variables were unset, `/tmp/umaxica-secret-db-task.rb` was absent, and no listener was present on
  ports 3443, 3192 or 3188.
- Device Session, DBSC and device-management paths had no diff. The full Rails suite was not run;
  the frozen plan reserves it for its later full-suite step.

The frozen plan states no locale keys for this mock were found. Search found the two now-unused keys
in each of `config/locales/{jp,us}/{en,ja}.yml`; only those keys were removed. Remaining active
references are the route-not-recognized and E2E-absence assertions. Historical evidence was
preserved.

## Commands

Rails tests ran through `scripts/test-isolated` against the verified task-owned PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, with a single worker and unique Valkey run IDs.
`RUBYOPT` preloaded `active_support/core_ext/enumerable` so the scoped cleanup could run.

```sh
bin/rails test test/controllers/auth/route_naming_test.rb test/controllers/auth/app/sign_ins_controller_test.rb
```

The regression run used these existing files:

```sh
bin/rails test \
  test/controllers/auth/app/sign_ins_controller_test.rb \
  test/controllers/auth/app/sign_in_admission_test.rb \
  test/controllers/auth/app/sign_in_boundary_test.rb \
  test/controllers/auth/app/social/ceremony_entry_test.rb \
  test/controllers/auth/app/in/passkeys_controller_test.rb \
  test/controllers/auth/app/in/passkey/authentication_flow_test.rb \
  test/controllers/auth/app/in/secrets_controller_test.rb \
  test/controllers/auth/app/in/emails_controller_test.rb \
  test/controllers/auth/app/in/emails_controller_enumeration_test.rb \
  test/controllers/auth/app/in/emails_controller_extra_test.rb \
  test/controllers/auth/app/in/emails_controller_security_test.rb \
  test/controllers/auth/org/in/emergency/passkeys_controller_test.rb \
  test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb \
  test/concerns/auth/org_emergency_session_continuity_test.rb
```

```sh
bundle exec rubocop \
  app/controllers/auth/app/sign/ins_controller.rb \
  config/routes/auth.rb \
  test/controllers/auth/app/sign_ins_controller_test.rb \
  test/controllers/auth/route_naming_test.rb
bun run test -- gait/features/auth/signin/signin_screens.test.tsx
```
