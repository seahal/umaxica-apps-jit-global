# CF-003/CF-004 and CF-007 current verification

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing staged, unstaged, and untracked changes were preserved.
- External activity: no GitHub, production, provider, AWS, Cloudflare, deployment, or shared
  database write was performed.

## Implemented pre-deployment slice

- Added the surface-local six-family authority lifecycle tables and concrete lifecycle models.
- Added explicit owner/lifecycle backfill operations, including an atomic complete-family operation
  with duplicate, incomplete, conflict, and replay handling.
- Kept legacy membership, assignment, administrator, identity-binding, and Organization data out
  of owner inference.
- Tightened the read-only family cutover guard to fail closed for missing lifecycle data,
  ineligible owners/resources, and an empty family.
- Added the approved 13-cell regional RP matrix contract with independent logical namespaces and
  RP-session bindings. Missing Side US host sources and regional audience sources remain explicit
  failures; no values were invented or activated.
- Preserved legacy bootstrap behavior for pre-cutover inactive/restricted flows and did not switch
  authorization consumers or create a rollback marker.

## Verification

The focused Compose-backed authority/RP suite was run with the explicit devcontainer environment,
the approved test-database preparation list, and one worker:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/authority_schema_contract_test.rb \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/operations/authority_owner_direct_binding_backfill_operation_test.rb \
  test/operations/authority_owner_predeployment_backfill_operation_test.rb \
  test/operations/authority_owner_family_backfill_operation_test.rb \
  test/operations/authority_owner_cutover_guard_test.rb \
  test/operations/authority_resource_lifecycle_backfill_operation_test.rb \
  test/services/acme/selector_bootstrap_authority_test.rb \
  test/services/acme/selector_bootstrap_authority_concurrency_test.rb \
  test/operations/identity_graph_provisioner_test.rb \
  test/values/regional_rp_client_matrix_test.rb

74 runs, 633 assertions, 0 failures, 0 errors, 0 skips
```

The read-only tasks were also executed. The cutover guard remained not ready: the empty approved
families are blocked as `empty_resource_family`, and the current Company family contains an
ineligible authoritative owner. The regional contract remained incomplete because the repository
does not provide canonical Side US hosts or regional audience values.

Syntax checks, scoped RuboCop, and `git diff --check` passed for the affected implementation and
test files. No test was deleted, skipped, weakened, or replaced with a mock to obtain these
results.

## Full-suite boundary

A full Rails run was started in the Compose-backed process, but the observed run emitted repeated
foreign-key fixture setup errors for pre-existing orphan references in the test database (including
`company_ownerships(visitor_id)` referencing an absent Visitor and
`client_authority_locks(client_id)` referencing absent Clients). Its final aggregate was not
retained when that process ended, so this record does not claim a current full-suite pass.

A subsequent process-local retry could not resolve the configured `primary` PostgreSQL service and
stopped before test assertions with:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No localhost substitution, environment fabrication, host-file edit, database reset, application
change, test deletion, skip, or mock was used to bypass either boundary. The earlier dated
Compose-backed full-suite records remain historical evidence and are not substituted for a current
full-suite result after this implementation slice.

## Blocker status

- `CF-003/CF-004`: `OPEN — IMPLEMENTATION REQUIRED`. The explicit lifecycle/backfill slice is
  present, but a complete reviewed mapping, family consumer cutover, point-of-no-return handling,
  and forward-recovery proof are not complete.
- `CF-007`: `OPEN — CONTRACT CONTRADICTION`. The approved logical matrix is present, but exact
  Side US URI sources and regional audience semantics are not uniquely defined in the repository.
- `CF-005` and `CF-011`: unchanged; no new evidence in this slice reopens them.

These statuses are pre-deployment statuses. Production inventory, deployment registration,
credential fingerprints, deployed callers, and provider E2E remain later acceptance gates.
