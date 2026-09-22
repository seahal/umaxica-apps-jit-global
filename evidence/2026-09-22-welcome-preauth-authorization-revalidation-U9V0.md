# Welcome and pre-auth authorization revalidation

## Scope

- Repository HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: already contained unrelated user changes; no existing changes were reset, staged, committed, or pushed.
- Date: 2026-09-22

## Repository finding

Base app/com/org Welcome controllers use the shared sign-in sequence gate. The gate authorizes the
pending sign-in cycle for checkpoint, dashboard, and return transitions through the cycle policy
before advancing or consuming the sequence. The Welcome controllers therefore do not need a
second direct `authorize!` call.

Auth app/com/org sign-in checks are pre-authentication sequence endpoints. Their security contract
is to authenticate the actor bound to the pending sequence and reject an invalid or mismatched
sequence; they do not authorize a normal authenticated resource action. Adding a separate
Action Policy call at this boundary would duplicate or misclassify the flow guard.

## Verification

Command:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/welcomes_controller_test.rb test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb test/controllers/auth/app/sign/in/checks_authorization_test.rb
```

Result: `15 runs, 171 assertions, 0 failures, 0 errors, 0 skips`.

The first attempted command named non-existent com/org `checks_authorization_test.rb` files and
stopped during test-file loading; it did not execute a test. The corrected command above used only
files present in the repository.

## Disposition

`ALREADY_SATISFIED`. No production code, route, policy, or test was changed for this finding.

