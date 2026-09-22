# Step-Up Session Revoke-All Boundary

Date: 2026-09-21
Target HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
Worktree: pre-existing uncommitted changes were present; this record covers only the
Step-Up changes listed below.

## Finding

The accepted assurance contract identifies self-service revoke-all as a sensitive operation:
`docs/security/authentication-assurance-levels.md` states that AAL1 does not permit
`session revoke-all`, and `adr/step-up-authentication-redesign.md` assigns the
`session_revoke_all` Step-Up scope to that operation. The three identity revoke-all controllers
authenticated the actor and authorized the token class, but did not evaluate Step-Up freshness.

The app compatibility secret-removal endpoint had the same omission. Its sibling com/org removal
controllers already declared the `settings_secret_credential` Step-Up scope, and the shared
credential-management documentation says dedicated removal routes require that scope.

## Change

- Added `settings_secret_credential` Step-Up to the app secret-removal endpoint.
- Added `session_revoke_all` Step-Up to app, com, and org identity revoke-all endpoints for both
  the `create` action and the routed `destroy` alias.
- Added public integration coverage for refusal without fresh Step-Up and for successful operation
  with the correct session-bound scope on the affected app/com/org paths.

## Verification

Passed:

- Ruby syntax checks for all changed controllers and tests.
- RuboCop for the five changed controller/test files: 5 files inspected, no offenses.
- `git diff --check` for the changed files.
- Static inspection confirmed all three revoke-all controllers declare both routed actions with
  `session_revoke_all`, and the app removal controller declares `settings_secret_credential`.

Blocked before test execution:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
  PARALLEL_WORKERS=1 bin/rails test \
  test/integration/identity_session_revocation_test.rb \
  test/controllers/base/org/identity/revocations/others_controller_test.rb
```

Rails stopped while maintaining the test schema because PostgreSQL host `primary` could not be
resolved:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No test assertion, failure count, or runtime behavior is claimed from this shell. The focused
tests remain required in the reachable core-service environment before this slice can be marked
runtime-verified.

## Adversarial review

- A stale or wrong-purpose Step-Up record is rejected by the existing session-bound resolver; the
  new declarations use the documented scopes rather than accepting a generic freshness marker.
- The `destroy` alias is included explicitly because a `before_action only: :create` declaration
  would not protect the routed DELETE action.
- Authentication and Action Policy checks remain in place; the change only adds the missing
  precondition and does not broaden ownership or session scope.
- GET routes remain navigation-only; no new mutation route or credential transport was introduced.

Status: implementation complete locally; runtime verification pending the existing PostgreSQL/
Valkey service reachability blocker.
