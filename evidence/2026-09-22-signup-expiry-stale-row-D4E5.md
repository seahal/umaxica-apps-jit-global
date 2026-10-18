# Sign-up expiry stale-row revalidation

- Date: 2026-09-22 UTC
- Repository HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing uncommitted changes were preserved; no external service or shared data
  store was modified.

## Scenario

An expiry sweep can select a row and hold an older Active Record instance while a legitimate
completion request commits on another database connection. The expiry operation must lock and
re-read the row before applying a terminal transition; it must not overwrite the completed flow or
run expiry cleanup against it.

## Verification

`SignUpExpiryRaceTest` creates a committed app sign-up flow, retains a stale instance, completes
the flow through `complete_sign_up!` on a separate PostgreSQL connection, advances the observed time
past the original expiry, and calls the public `SignUpTermination` expiry operation with the stale
instance.

Command:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/services/sign_up_expiry_race_test.rb
```

Result: `1 run, 4 assertions, 0 failures, 0 errors, 0 skips`.

The related expiry, termination-idempotence, and artifact-cleanup focused set also passed with
`15 runs, 63 assertions, 0 failures, 0 errors, 0 skips`.

After adding this regression, the full Rails suite passed with `11,503 runs, 73,303 assertions,
0 failures, 0 errors, 5 skips`. The skips and expected provider/OmniAuth diagnostics were not
changed by this test.

The expiry operation rejected the stale transition as invalid and the persisted flow remained
`COMPLETED`. This verifies the repository-side stale-row/row-lock boundary. It does not prove
production scheduler topology, worker retry behavior, or a live completion request racing a worker
at the exact same instant; those remain part of CF-005's operational gate.
