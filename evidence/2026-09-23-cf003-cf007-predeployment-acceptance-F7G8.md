# CF-003/CF-004 and CF-007 pre-deployment acceptance recheck

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were present; this run did not create a commit.
- External activity: no production, provider, AWS, Cloudflare, Base registry, or GitHub write.

## Environment preflight

The run used the explicit `.env.devcontainer.example` environment and did not print secret
values. `config/credentials/test.key` was present. All required PostgreSQL, Valkey, and test
database-list variables were present. The service names `primary` and `valkey-kvs` resolved in the
Compose-backed network context available to the test process.

The required preflight command completed successfully:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

Observed service versions were PostgreSQL 17.7 and Valkey 7.2.4. Valkey PING succeeded for the
rate-limit and auth-state logical databases. No production or shared database was used.

The disposable local test databases were rebuilt after stale fixture/worker-clone data caused
foreign-key setup failures. Validated test-only parallel database clones were also removed so the
next full suite could recreate them from the current schema/data. No application fallback,
hostname rewrite, constraint weakening, test skip, test deletion, or mock substitution was used.

## Acceptance tests

The CF-003/CF-004 focused acceptance set was:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/authority_schema_contract_test.rb \
  test/operations/authority_owner_cutover_guard_test.rb \
  test/operations/authority_owner_direct_binding_backfill_operation_test.rb \
  test/operations/authority_owner_family_backfill_operation_test.rb \
  test/operations/authority_owner_family_cutover_concurrency_test.rb \
  test/operations/authority_owner_family_cutover_operation_test.rb \
  test/operations/authority_owner_predeployment_backfill_operation_test.rb \
  test/operations/authority_resource_lifecycle_backfill_operation_test.rb \
  test/operations/client_persona_creator_concurrency_test.rb \
  test/operations/client_persona_creator_test.rb \
  test/operations/enterprise_creator_test.rb \
  test/operations/identity_graph_provisioner_test.rb \
  test/operations/surface_resource_creators_test.rb \
  test/policies/acme/owner_quota_surface_mapping_test.rb \
  test/queries/authority_owner_migration_inventory_test.rb \
  test/queries/authority_owner_resource_scope_query_test.rb \
  test/policies/account_policy_test.rb
```

Result:

```text
97 runs, 690 assertions, 0 failures, 0 errors, 0 skips
```

The focused set exercised the approved six surface-local mappings, lifecycle and conflict
dispositions, explicit-owner backfill, atomic/idempotent family backfill, unique-owner and
cross-surface rejection, family cutover gating, immutable cutover markers, post-marker backfill
rejection, and post-cutover explicit ownership reads.

The Rails full suite was then run with the same environment:

```text
bin/rails test
```

Result:

```text
11672 runs, 74218 assertions, 0 failures, 0 errors, 8 skips
```

The eight skips were reported by the existing suite; no skip was added in this run. The first
fresh full-suite attempt exposed two test-contract issues: a CSRF log assertion matched Rails
debug exception continuation text rather than the framework warning, and two new quota-boundary
fixtures attempted to violate the existing unique `ClientIdentity.source_record_id` contract.
The tests were corrected without changing CSRF protection or production ownership behavior, their
focused regression run passed with `13 runs, 46 assertions, 0 failures, 0 errors, 0 skips`, and
the full suite was rerun successfully.

## Static checks

The following checks passed for the corrected regression tests:

```text
ruby -c test/integration/csrf_notification_emission_test.rb
ruby -c test/operations/client_persona_creator_test.rb
bin/rubocop test/integration/csrf_notification_emission_test.rb \
  test/operations/client_persona_creator_test.rb
git diff --check -- test/integration/csrf_notification_emission_test.rb \
  test/operations/client_persona_creator_test.rb
```

RuboCop reported no offenses. Coverage was not evaluated in accordance with the current task
instruction.

## Disposition

`CF-003/CF-004`: `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`. This is limited to the approved
repository/design/isolated-test scope. Production row inventory, live authority cutover, and
operational forward-recovery rehearsal remain deployment gates.

`CF-007`: remains `OPEN — CONTRACT CONTRADICTION`. The approved 13-cell logical matrix and
cross-region isolation contract are tested, but no canonical repository source supplies the Side
US host or regional audience semantics. No value was guessed, generated from a Host header, or
activated.
