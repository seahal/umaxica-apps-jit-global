# CF-003/CF-004 and CF-007 pre-deployment recheck

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were present; this record does not claim ownership of unrelated changes.
- Scope: approved pre-deployment repository review only. No production, provider, AWS, Cloudflare, Base deployment registry, or external credential access was attempted.

## Review result

`CF-003/CF-004` remains `OPEN — EVIDENCE REQUIRED`. The approved six surface-local mappings are
represented by `AuthorityOwnerMigrationInventory`. The family backfill is explicit-owner,
surface-scoped, atomic, idempotent, and conflict-rejecting. The family marker is immutable; a
post-marker backfill is rejected. `AccountPolicy` uses the explicit owner and active lifecycle
after the relevant family marker, while quota policies and creator operations use the explicit
ownership/lifecycle boundary for owner-specific quota decisions. Selector/switcher and
`OrganizationPolicy` remain delegated/member contracts and were not converted to owner-only reads.
Ownership-transfer acceptance is not enabled because its recipient authentication, step-up,
lifecycle, quota, and locked acceptance transaction are not defined by the approved pre-deployment
contract. No recovery API was invented.

`CF-007` remains `OPEN — DECISION REQUIRED`. The approved 13-client logical matrix and independent
logical key namespaces are present. URI derivation is fail-closed and uses repository sources only.
The repository has no independent Side US canonical host source and no regional audience SSOT for
the new IDs. The old seven-client registry and `core-next-rp` compatibility path therefore remain
unchanged. No client, key, audience, URI, or registry entry was guessed or activated.

## Verification performed

- `config/credentials/test.key`: present; contents were not displayed.
- With `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`, all required PostgreSQL,
  Valkey, and test-database variables were present; values were not displayed.
- `bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'`:
  blocked before completion by `PG::ConnectionBad: could not translate host name "primary" to address:
  Temporary failure in name resolution`.
- `getent hosts primary` and `getent hosts valkey-kvs`: no result in the current process.
- Podman executable/socket: not visible in the current process.
- Ruby syntax checks for the affected authority, policy, and regional-matrix files: passed.
- RuboCop on 15 affected implementation/test files: `15 files inspected, no offenses detected`.
- `bundle exec brakeman --no-pager`: passed, 0 errors, 0 security warnings.
- `git diff --check`: passed.
- Focused Rails command was attempted with `PARALLEL_WORKERS=1`; Rails stopped during test-schema inspection before assertions with the same unresolved `primary` host error. No test runs or assertions were produced.
- Full Rails suite was not started because the focused prerequisite did not pass.

No application or test change was made to bypass the missing services. No external service was
contacted or changed.

## Adversarial review findings

- Multiple, zero, inactive-only, membership-only, administrator-only, legacy-only, and
  cross-surface owner candidates remain reject/manual-review cases; no tie-breaker was found in
  the reviewed backfill path.
- A partial family backfill cannot be accepted as a cutover: the family operation requires the
  complete resource set and rolls back the batch on a later conflict.
- A concurrent cutover/backfill race is serialized by the family resource-table lock; the marker
  is immutable and reviewed backfill rejects after it exists. This is the forward-only boundary,
  not an ownership-transfer implementation.
- Replacing selector/switcher membership and act-as resolution with owner-only reads would break
  delegated access and was rejected as an out-of-scope architecture change.
- JP/US credential, URI, audience, namespace, and RP-session cross-acceptance is represented as a
  fail-closed contract. An arbitrary Host header cannot create a matrix cell. Activation remains
  blocked rather than accepting an incomplete or guessed regional registration.
