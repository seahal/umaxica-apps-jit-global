# Dashboard and sign-out notice revalidation

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Scope: close the earlier local verification gap for Valkey-backed sign-out notices and the
  Base app/com/org sign-out controllers.
- Worktree: pre-existing modified and untracked files were present; no source or test file was
  changed for this verification.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database,
  email, or SMS service was contacted or modified.

## Environment

The test ran from the Compose-backed test environment with the repository's explicit devcontainer
environment file and isolated test database preparation list. PostgreSQL and Valkey were reachable;
secret values were not printed.

## Command

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
PARALLEL_WORKERS=1 bin/rails test test/services/valkey/auth_state/sign_out_notice_store_test.rb test/controllers/base/app/sign_outs_controller_test.rb test/controllers/base/com/sign_outs_controller_test.rb test/controllers/base/org/sign_outs_controller_test.rb
```

## Result

```text
22 runs, 116 assertions, 0 failures, 0 errors, 0 skips
```

The Valkey sign-out notice store's one-shot consumption, retained reads, expiry behavior, blank
identifier rejection, and payload validation passed. The three Base surface sign-out controller
contracts also passed. This removes the earlier local test-service availability blocker for this
focused reachability slice.

Live deployment reachability, Cloudflare Tunnel behavior, production worker topology, and external
logout providers remain outside this repository-side verification.
