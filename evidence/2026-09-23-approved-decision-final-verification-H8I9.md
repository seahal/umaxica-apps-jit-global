# Approved decision final verification

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were preserved; this verification did not reset,
  stage, commit, or discard them.
- External activity: no GitHub, provider, AWS, Cloudflare, production, or shared external service
  write was performed.
- Coverage: intentionally not run for this cycle, as requested.

## Focused acceptance

With `.env.devcontainer.example` selected and the isolated Compose PostgreSQL/Valkey services
reachable, the following focused set passed:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/values/regional_rp_client_matrix_test.rb \
  test/values/auth_boundary_authority_map_test.rb \
  test/operations/authority_owner_family_backfill_operation_test.rb \
  test/operations/authority_owner_family_cutover_operation_test.rb \
  test/operations/authority_owner_family_cutover_concurrency_test.rb \
  test/operations/authority_owner_predeployment_backfill_operation_test.rb \
  test/operations/authority_owner_cutover_guard_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/models/processor_erasure_notification_delivery_contract_test.rb \
  test/jobs/processor_erasure_notification_retry_job_test.rb
```

Result: `88 runs / 503 assertions / 0 failures / 0 errors / 0 skips`.

## Full Rails suite

```text
bin/rails test
```

Result: `11,672 runs / 74,218 assertions / 0 failures / 0 errors / 8 skips`.

The eight skips are pre-existing; no test was deleted, added to the skip list, weakened, or
mocked to obtain this result.

## Static checks

- `ruby -c` for the two corrected test files: passed.
- `git diff --check`: passed.
- The existing scoped RuboCop evidence for the implementation slice remains clean.

## Contract-task observations

- `auth:regional_rp_contract` remains fail-closed: `edit-org` is complete from the existing
  global source; the regional cells lack canonical audience values, and the Side US cells also
  lack a canonical host source. No registration or credential was activated.
- `RAILS_ENV=test bundle exec rails authority:cutover_guard` returns `ready: false` for all six
  families because the isolated inventory is empty. The development invocation fails closed on a
  partially applied authority schema rather than treating missing lifecycle/cutover tables as
  active. Neither result was used as false acceptance evidence.

## Disposition

The repository-side pre-deployment implementations covered by the approved decision are
regression-clean. CF-003/CF-004, CF-005, and CF-011 remain closed for pre-deployment acceptance.
CF-007 remains `OPEN — CONTRACT CONTRADICTION` until canonical Side US host and regional audience
sources exist; no value was guessed. CF-008 remains separately blocked by its unapproved scrub
data contract. Production/deployment/provider gates remain later acceptance stages.
