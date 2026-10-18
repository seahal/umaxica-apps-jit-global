# Auth/Base OIDC root-session regression

- Scope: public OIDC browser-flow proof that Auth does not create a Base Browser Session.
- Verification date: 2026-09-21
- Repository HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing staged, unstaged, and untracked changes were present; this check
  was run without resetting or staging unrelated work.

## Contract

An OIDC-started Auth ceremony records authentication evidence and issues only the opaque
Auth-to-Base result. Auth must not call the root-session login path or create a ClientToken.
Base creates the Browser Session when it resumes the authenticated authorization transaction.

## Change and focused verification

`test/integration/oidc_rp_browser_flow_test.rb` now records the active ClientToken count before
the Auth OIDC handoff and asserts that the count is unchanged immediately after the handoff.
The same public flow continues to assert that Base creates the expected session during the
authorization resume path.

Command:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_browser_flow_test.rb
```

Result: `13 runs, 119 assertions, 0 failures, 0 errors, 0 skips`.

## Broader verification

Command:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
bin/rails test
```

Result: `11500 runs, 73298 assertions, 0 failures, 0 errors, 5 skips`.

Additional checks:

- `bin/rubocop test/integration/oidc_rp_browser_flow_test.rb`: no offenses.
- `git diff --check -- test/integration/oidc_rp_browser_flow_test.rb`: clean.
- Coverage was not run by request; no coverage claim is made.

## Remaining boundary

This evidence closes only the Auth-side root-session creation regression coverage. It does not
claim completion of the separate Auth/Base issuer migration, regional RP registration, shared
browser-client retirement, content-surface RP retirement, or external RP/edge configuration.
