# Step-Up sensitive-write runtime revalidation

## Scope

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Existing staged, unstaged, and untracked work was preserved. No reset, cleanup, commit, GitHub
  write, deployment, production/shared database mutation, or external provider call was performed.

This revalidation covers the repository-owned sensitive-write gates associated with #884 after the
current Compose-backed PostgreSQL and Valkey test services became reachable.

## Findings

- Credential removal, credential configuration, email/telephone changes, MFA reset, social unlink,
  withdrawal, and session revoke-all continue to require their existing session-bound Step-Up
  scopes.
- The app, com, and org revoke-all paths cover both routed mutation actions; the Step-Up scope is
  not limited to only the legacy create alias.
- Emergency/restricted authentication contexts are rejected before a Step-Up credential is
  requested on the protected paths.
- Privacy erasure and withdrawal retain their dedicated ceremony and subject checks; they were not
  replaced with a generic Step-Up gate.
- App Group and Group Avatar Membership writes remain outside a newly invented generic Step-Up
  scope. Their authority meaning and assurance classification remain unresolved in the accepted
  architecture, so this review does not claim those operations are classified as complete.

## Verification

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db
PARALLEL_WORKERS=1 bin/rails test \
  test/integration/step_up_authentication_test.rb \
  test/integration/step_up_required_response_shape_test.rb \
  test/integration/identity_session_revocation_test.rb \
  test/integration/sign/app/credential_removal_constraints_test.rb \
  test/integration/sign/com/credential_removal_constraints_test.rb \
  test/integration/sign/org/credential_removal_constraints_test.rb \
  test/controllers/base/app/identity/mfa/resets_controller_test.rb \
  test/integration/social_link_unlink_test.rb \
  test/integration/social_auth_step_up_test.rb \
  test/integration/app_withdrawal_step_up_enforcer_test.rb \
  test/integration/org_step_up_verification_enforcer_test.rb \
  test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb
```

Result: `76 runs, 290 assertions, 0 failures, 0 errors, 0 skips`.

## Disposition

The defined sensitive-write Step-Up contracts are runtime-verified on the current checkout. The
remaining Group/Avatar membership classification is `NEXT_CYCLE / CONTRACT_UNDEFINED`, not a
silently accepted missing gate. No CSRF, authentication, authorization, verification, rate-limit,
or emergency-context control was weakened.
