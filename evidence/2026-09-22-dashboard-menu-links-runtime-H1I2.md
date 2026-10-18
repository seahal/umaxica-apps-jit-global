# Base Dashboard menu-link runtime revalidation

- Date: 2026-09-22 UTC
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Scope: runtime revalidation of the signed-in Base app/com/org Dashboard Menu/Primary contract.
- Worktree: pre-existing modified and untracked files were preserved; no unrelated changes were
  reverted and no source or test file was changed for this revalidation.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Focused verification

The Compose-backed test environment was selected explicitly:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db
PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/welcome_dashboard_authority_slice_1c_test.rb test/controllers/base/com/welcome_dashboard_authority_slice_1c_test.rb test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb
```

Result: `19 runs, 267 assertions, 0 failures, 0 errors, 0 skips`.

The public rendered-Inertia-props assertions verified that all three surfaces put `Menu links`
before `Primary links`, preserve the surface-specific Switcher/Selector distinction, include
Preference and Logout, avoid duplicate menu URLs in Primary links, preserve the remaining links,
and propagate `ri`, `ct`, `lx`, and `tz` through the route helpers.

## Regression verification

```text
bin/rails test
```

Result: `11536 runs, 73426 assertions, 0 failures, 0 errors, 8 skips`.

Expected provider-failure and CSRF-rejection diagnostics were emitted by negative OmniAuth tests;
none corresponded to a failing test. The eight skips were pre-existing and were not changed.

## Disposition

`ACCEPTED_AS_EXISTING_IMPLEMENTATION`. No dashboard code, route, authentication, authorization,
API, JSON, or global-navigation behavior was changed. Live deployment reachability remains
unverified.
