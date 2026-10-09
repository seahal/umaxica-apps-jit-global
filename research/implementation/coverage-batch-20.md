# Coverage Batch 20

Date: 2026-07-05 UTC

## Summary

This retry batch stayed test-only and focused on low-risk coverage gaps in pure value objects and
deterministic helpers. It restored the Rails test database state, added a handful of narrow branch
tests, and completed the required full Rails and VP coverage passes.

## Coverage Snapshot

- Starting Rails coverage: 90.65% line coverage, 69.48% branch coverage.
- Ending Rails coverage: 90.71% line coverage, 69.56% branch coverage.
- Starting VP coverage: 0% lines, 0% statements, 0% branches, 0% functions.
- Ending VP coverage: 0% lines, 0% statements, 0% branches, 0% functions.

## Failures / Errors

- Starting failures / errors: 1 failure, 0 errors.
- Ending failures / errors: 1 failure, 1 error.
- The remaining Rails issues in the full coverage run were:
  - `ClientSecretCredentialKindTest#test_validates_id_is_non_negative`
  - `SignAppOidcBrowserFlowTest#test_sign_app_settings_auth-required_sso_resolves_an_existing_acme_session_and_returns_to_settings`
    with `ActiveRecord::NoDatabaseError` for `test_app_setting_replica_db`

## Selected Targets

1. `JumpRtSurface.namespace_for_controller` ACME branch
2. `JumpRtSurface.normalize_namespace` failure branch
3. `SignInSequence.missing`
4. `SignInSequence#parse_time` rescue branch
5. `ConfigValues::HostFamilyValues#auth_service` alias path
6. `ConfigValues::HostFamilyValues#auth_corporate` alias path
7. `ConfigValues::HostFamilyValues#auth_staff` alias path
8. `ConfigValues::HostFamilyValues#auth_origins`
9. `JitHostOriginEnv.origins_for` malformed-origin path
10. `OidcClientAssertionJwt.issue` second rescue path

## Tests Added

- `test/services/jump_rt/issuer_test.rb`
  - added ACME namespace coverage
  - added unsupported namespace failure coverage
- `test/policies/sign_in_sequence_policy_test.rb`
  - added `SignInSequence.missing` coverage
  - added invalid timestamp rescue coverage
- `test/lib/config_values/host_family_values_test.rb`
  - added `auth_service`, `auth_corporate`, `auth_staff`, and `auth_origins` coverage
- `test/lib/jit/host_origin_env_test.rb`
  - added malformed explicit-origin coverage
- `test/services/oidc_client_assertion_jwt_test.rb`
  - added the fallback-rescue nil path when refresh still cannot resolve the configured key

## App / DB Changes

- No application code changed.
- The test schema was advanced with `RAILS_ENV=test bin/rails db:migrate` so the narrow Rails tests
  could boot.

## Dead-Code Evidence

- None. No code deletion was attempted.

## Commands Run

- `RAILS_ENV=test bin/rails db:migrate`
- `bin/rails test test/services/jump_rt/issuer_test.rb test/policies/sign_in_sequence_policy_test.rb`
- `bin/rails test test/services/jump_rt/issuer_test.rb test/policies/sign_in_sequence_policy_test.rb test/lib/config_values/host_family_values_test.rb test/lib/jit/host_origin_env_test.rb test/services/oidc_client_assertion_jwt_test.rb`
- `vp check --fix`
- `bundle exec rubocop -a`
- `bin/rails test test/services/jump_rt/issuer_test.rb test/policies/sign_in_sequence_policy_test.rb test/lib/config_values/host_family_values_test.rb test/lib/jit/host_origin_env_test.rb test/services/oidc_client_assertion_jwt_test.rb`
- `COVERAGE=true bin/rails test test/`
- `vp test --coverage`

## Skipped Risky Areas

- `config/**`, `bin/**`, fixtures, factories, routes, CI files, and dependency files were left
  untouched.
- Auth/session/OIDC/security flows were not modified beyond test coverage additions.
- `vp check --fix` still reports pre-existing TypeScript issues in `src/entrypoints/inertia.tsx` and
  `@styles/application.css`, which are outside the allowed edit scope for this batch.

## Next Batch Candidates

- Continue with the remaining single-line Rails gaps in deterministic files such as
  `app/models/concerns/step_up_ceremony_transactionable.rb`,
  `app/models/concerns/single_use_token.rb`,
  `app/services/identity_social_ceremony_final_committer.rb`,
  `app/services/identity_secret_credential_ceremony_final_committer.rb`, and
  `lib/config_values_host_family_values.rb` if additional uncovered branches remain after the new
  full-suite report.
- Re-check the full Rails resultset before selecting the next batch so the next target list is based
  on the current coverage artifact.
