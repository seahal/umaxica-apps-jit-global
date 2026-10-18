# OIDC authorization transaction concurrency test

- Date: 2026-09-21
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: dirty before and after this verification; unrelated staged, unstaged, and untracked changes were preserved.
- Scope: strengthen the regression test for the pending-to-authenticated OIDC authorization transaction transition.

## Finding and change

The existing test used `Concurrent::Promises.future` but did not disable transactional fixtures,
release the setup connection, or synchronize independent database workers. It therefore did not
prove that two committed PostgreSQL transactions raced on the same row lock.

The test now uses committed setup/teardown, a per-test challenge namespace, a queue barrier, and
two connections checked out from the `VisitorOidcAuthorizationTransaction` connection pool. The
production state transition was not changed.

## Verification

Focused command:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb
```

Result: `8 runs, 44 assertions, 0 failures, 0 errors, 0 skips`.

Static checks:

```text
bundle exec rubocop test/models/concerns/oidc_authorization_transactionable_test.rb
git diff --check -- test/models/concerns/oidc_authorization_transactionable_test.rb
```

Result: no RuboCop offenses and no diff-check errors.

Full command:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db bin/rails test
```

Result: `11500 runs, 73296 assertions, 0 failures, 0 errors, 5 skips`.

Coverage was not run, as explicitly requested. No production data, external service, GitHub
resource, or non-test database was modified. One row left by the intentionally interrupted first
attempt was removed from the isolated test database by its exact test challenge values only.

## Remaining boundary

This evidence proves the row-lock race test is real and green. It does not prove the complete
Auth/Base issuer migration, the cross-store Valkey/PostgreSQL failure protocol, or external RP
registration. Those remain separate plan blockers.
