# Authority backfill and regional RP contract slice

- Date: 2026-09-23
- Repository: `/home/global/workspace`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained extensive uncommitted changes; this verification includes the
  authority backfill and regional RP files changed in this cycle. No commit, push, or external
  write was performed.

## Changes reviewed

- `AuthorityOwnerPredeploymentBackfillOperation` now composes one explicitly reviewed owner public
  identifier and one explicitly reviewed lifecycle state in a single surface-local transaction.
- A rejected lifecycle conflict rolls back an owner row created by that unit. Repeating the same
  pair is idempotent. The operation does not infer owners or switch runtime authorization readers.
- The public operation test covers the same reviewed pair contract across all six approved
  surface-local resource families.
- `BaseSelectorBootstrapAuthority` now delegates newly created accounts and collectives to the
  surface-local creator operations. Its public bootstrap tests assert that new app/com/org
  resources receive the matching ownership row and `active` lifecycle row. Existing resources are
  not inferred or repaired by this path.
- The family cutover guard tests also cover an inactive resource lifecycle as unresolved; no
  ownership row alone can make that family cutover-ready.
- A read-only `authority:cutover_guard` task now evaluates all six families and writes a bounded
  readiness report without changing data or authorization consumers.
- A read-only `auth:regional_rp_contract` task now evaluates all 13 approved RP IDs and reports
  missing canonical hosts/audiences or invalid registrations without activating clients or keys.
- Regional RP contract tests cover exact US URI/namespace acceptance and JP/US redirect, namespace,
  and actor-resource-type rejection. The active seven-client registry remains unchanged because
  the repository still lacks a canonical Side US host and a unique regional audience source.

## Static verification

Passed:

- Ruby syntax checks for the new operation and tests.
- Targeted RuboCop for the new operation, its tests, the cutover guard, and regional RP matrix:
  no offenses.
- `git diff --check`.
- `bundle exec brakeman --no-pager`: 0 errors, 0 security warnings.

## Additional adversarial review

The selector/switcher path was reviewed as a possible owner-authority consumer. It is not one:
it resolves an act-as context through identity, assignment, membership, and avatar contracts,
while the approved decision defines ownership as a separate authority fact. A blanket replacement
with owner-only queries would remove legitimate delegated/member access and would introduce an
unapproved access-contract decision. The selector path therefore remains unchanged in this slice;
owner-specific quota and backfill/cutover boundaries use the explicit ownership relations.

This is a deliberate scope decision, not an implementation omission. A later consumer cutover must
identify an owner-specific authorization decision and test its interaction with delegated access
before changing selector/switcher behavior.

## Bootstrap concurrency correction

Adversarial review found that creator-local locks did not serialize the entire selector bootstrap:
two callers could both observe no membership before separate collective creation. The bootstrap
now acquires the existing surface-local authority lock before its complete graph transaction, and
an independent-connection com bootstrap concurrency test asserts one account, one collective,
one membership, and one active lifecycle row. The test was added but could not execute in this
process because the required PostgreSQL service name `primary` remains unresolved; no runtime pass
is claimed.

The focused Rails command was then attempted with `PARALLEL_WORKERS=1` for the bootstrap,
concurrency, backfill, cutover-guard, inventory, and regional-RP tests. It stopped during Rails
test-schema boot with the complete boundary error `ActiveRecord::DatabaseConnectionError: There
is an issue connecting with your hostname: primary` followed by
`PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name
resolution`. It reached 0 test runs and 0 assertions; the full suite was not started because the
focused prerequisite did not pass.

The follow-up review also re-ran the required preflight after selecting
`.env.devcontainer.example`; it again failed before Rails boot with `PG::ConnectionBad` because
`primary` could not be resolved. The test key remained presence-checked only, all required
environment variable names were present after loading, and `getent hosts primary` and
`getent hosts valkey-kvs` remained unresolved. The follow-up targeted RuboCop run covered the
selector config, bootstrap, existing bootstrap test, and the new concurrency test (4 files);
Ruby syntax checks and `git diff --check` passed. No Rails focused test, full suite, migration,
database task, or cutover task was represented as executed from this process.
- Revalidation after adding the read-only regional contract task: targeted RuboCop inspected 14
  implementation/test/task files with no offenses; `git diff --check` passed; Brakeman again
  reported 0 errors and 0 security warnings.
- After the bootstrap integration slice: Ruby syntax checks and targeted RuboCop for the bootstrap
  service/test passed; Brakeman again reported 0 errors and 0 security warnings.

## Runtime verification

The required preflight was run after selecting the repository's devcontainer environment file and
preparing the requested test database list:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

It did not reach Rails tests because the current process cannot resolve the Compose service name:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`config/credentials/test.key` was confirmed present without reading its contents. After loading the
selected environment file, the required PostgreSQL, Valkey, and prepared-database variables were
present. `getent hosts primary` and `getent hosts valkey-kvs` were unresolved in this process. No
application code, test, configuration, hosts file, database, or external service was changed to
bypass this environment boundary. Focused Rails tests and the full suite remain unexecuted in this
process. The new `authority:cutover_guard` task was not executed for the same reason; no readiness
report was represented as runtime evidence. The new regional RP contract task was likewise not
executed; no 13-cell acceptance report was represented as runtime evidence.

## Acceptance boundary

This record proves only the repository-side static slice. It does not prove database migration,
backfill, bootstrap runtime execution, concurrency, family consumer cutover, post-cutover forward recovery, live regional
registration, deployed callers, or production credentials. Those checks remain unverified or later
deployment gates.
