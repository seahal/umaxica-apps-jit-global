# Current Rails coverage gate

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- External writes: none

## Command

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
COVERAGE=true bin/rails test test/
```

The configured PostgreSQL and Valkey services were reachable and all Rails tests completed:

```text
11483 runs, 73355 assertions, 0 failures, 0 errors, 6 skips
```

The process exited with code 2 because the existing SimpleCov thresholds were not met:

- line: `95.95%` (`98.00%` minimum)
- branch: `75.01%` (`90.00%` minimum)
- method: `90.89%` (`95.00%` minimum)

The lowest-coverage files reported by the current run included
`app/controllers/concerns/oidc_rp_identity_provisioning.rb`,
`app/controllers/concerns/mcp_endpoint.rb`, `app/controllers/concerns/sign_verification_timing.rb`,
`app/models/concerns/retention_hold_state.rb`, and
`app/controllers/core/org/oidc/authorizations_controller.rb`.

No threshold, exclusion, assertion, or skip was changed to obtain this result. The coverage gate
is therefore an open quality-gate item, not a test failure and not a green release claim.

## Serial revalidation

To rule out parallel coverage aggregation as the cause, the full suite was rerun with:

```text
PARALLEL_WORKERS=1 COVERAGE=true bin/rails test test/
```

The Rails tests still completed successfully:

```text
11483 runs, 73499 assertions, 0 failures, 0 errors, 6 skips
```

SimpleCov still exited with code 2:

- line: `95.95%` (`98.00%` minimum);
- branch: `75.02%` (`90.00%` minimum);
- method: `91.94%` (`95.00%` minimum).

This confirms that the gate deficit is not resolved by changing worker aggregation. No threshold,
exclusion, assertion, or skip was changed.
