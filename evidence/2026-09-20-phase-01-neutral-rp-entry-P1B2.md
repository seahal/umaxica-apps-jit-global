# Phase 01 neutral browser RP entry verification

Date: 2026-09-20  
Repository: `seahal/umaxica-apps-jit-global`  
Phase: 01 — authority boundary and canonical browser RP entry

## Scope

The browser RP entry contract was changed to the neutral `GET /sign`, CSRF-protected
`POST /sign`, and registered `GET /sign/callback` paths for Core app/com/org, Side
app/com/org, and Edit org. The old RP `/sign/in` and `/sign/in/callback` aliases were
removed. Auth's internal `/sign/in/*` ceremony routes were not changed.

The new entry does not create an OIDC transaction on GET, does not expose a sign-in versus
sign-up choice, uses the existing state-indexed pending-flow path on POST, and refuses an
already authenticated browser at the server-side POST boundary. Rails CSRF protection was
not weakened.

## Verification performed

Environment was loaded with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`.

Focused behavior tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/integration/routes/neutral_rp_entry_contract_test.rb \
  test/controllers/side/app/roots_controller_test.rb \
  test/controllers/side/com/roots_controller_test.rb \
  test/controllers/side/org/roots_controller_test.rb \
  test/controllers/side/app/dashboards_controller_test.rb \
  test/controllers/side/com/dashboards_controller_test.rb \
  test/controllers/side/org/dashboards_controller_test.rb \
  test/unit/security/public_entrypoint_inventory_test.rb

24 runs, 314 assertions, 0 failures, 0 errors, 0 skips
```

Additional route, title, RI, architecture, and Core boundary checks:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/unit/security/ri_routing_contract_test.rb \
  test/tooling/architecture_baseline_test.rb \
  test/integration/layout_title_contract_test.rb \
  test/controllers/core/bff_surface_smoke_test.rb \
  test/controllers/core/auth_boundary_test.rb \
  test/integration/routes/neutral_rp_entry_contract_test.rb

24 runs, 3868 assertions, 0 failures, 0 errors, 0 skips
```

Static analysis:

```text
bin/rubocop <26 Phase 01 Ruby files>
26 files inspected, no offenses detected
```

Full Rails suite:

```text
bin/rails test
11338 runs, 72375 assertions, 0 failures, 0 errors, 5 skips
```

## Findings and boundaries

The first full-suite run exposed twelve contract-follow-up failures: stale Side route
helpers, public-entrypoint inventory coverage, the RI skip allowlist, hand-rolled title
markup, and tests still using the retired RP callback path. These were corrected and the
focused and full suites were rerun successfully.

The existing Jump RT mapping does not provide Side/Edit namespaces in this change. Core
POST `/sign` flow creation was verified end to end with the repository's existing test
Jump RT setup. Side/Edit POST redirect completion remains a bounded compatibility item for
the later approved Jump RT compatibility phase; no new Jump key, namespace, or trust
boundary was introduced here.

No production or remote database was reset. No GitHub or external service was modified.
