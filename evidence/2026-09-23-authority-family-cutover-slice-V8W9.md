# Authority family cutover slice

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were present; this record does not claim ownership of unrelated changes.
- Scope: CF-003/CF-004 pre-deployment cutover boundary only.

## Implemented

- Added one surface-local singleton cutover marker for each of the six approved resource families.
- Added the family cutover operation, which locks the concrete resource table, rechecks the
  fail-closed family guard, and records the database-clock cutover timestamp.
- Reviewed owner and lifecycle backfill paths now reject after the family marker exists.
- Selector bootstrap rejects a new ineligible resource after its family marker exists instead of
  entering the legacy-only resource path.
- Added migration/source-contract and operation tests for establishment, unresolved families,
  idempotent replay, post-marker backfill rejection, and marker immutability.
- Added a public bootstrap regression test proving that an ineligible new account cannot enter the
  legacy-only resource path after its account-family marker exists.
- Added `AuthorityOwnerResourceScopeQuery` and routed both owner-specific quota policies through it;
  the query accepts only the configured surface-local principal/resource family and has no legacy
  identity, membership, assignment, or organization fallback.
- Staged the owner-specific `AccountPolicy` on the immutable family marker. Before the account
  family marker it preserves the legacy behavior; after the marker it requires the explicit
  ownership relation, eligible principal, and active resource lifecycle, and no longer uses the
  legacy identity binding. `OrganizationPolicy` and selector/switcher delegated access remain
  intentionally unchanged.
- Scoped inventory and cutover checks to the requested surface/family so an unrelated surface
  database is not a hidden prerequisite for a surface-local migration operation.

## Verification performed

- Ruby syntax checks for all changed Ruby and migration/test files: passed.
- Targeted RuboCop for the changed slice: passed; 19 files inspected, no offenses.
- `bundle exec brakeman --no-pager`: passed; 0 errors and 0 security warnings.
- `git diff --check`: passed.
- The added bootstrap regression test was syntax-checked but could not execute because the Rails
  test boot could not resolve the isolated PostgreSQL host described below.
- The owner-scope query and quota-policy tests were included in a focused Rails attempt; they also
  stopped before test execution at the same PostgreSQL DNS failure.
- The new post-cutover `AccountPolicy` tests were included in the same focused attempt and therefore
  remain unexecuted in this process; no runtime acceptance is claimed for this policy slice.

## Runtime verification

The required focused Rails test command was attempted after setting
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the approved test database
list. Rails boot stopped before test execution because PostgreSQL host `primary` could not be
resolved (`PG::ConnectionBad: could not translate host name "primary" to address: Temporary
failure in name resolution`). The current focused command covered
`test/policies/account_policy_test.rb` and
`test/queries/authority_owner_resource_scope_query_test.rb`; it completed with 0 runs and 0
assertions because Rails stopped during schema maintenance. `getent hosts primary` and
`getent hosts valkey-kvs` both reported unresolved in this process. No localhost substitution,
application bypass, test deletion, skip, or mock replacement was used. The full Rails suite was not
run because the focused command did not complete successfully.

The exact preflight command was also run with the same environment selection. The credentials key
was present and no secret value was printed. The preflight stopped at
`scripts/test-environment-check:29` with the same PostgreSQL DNS error before a database or Valkey
connection could be established. The current process had no Podman or Docker executable available,
so no container transition was attempted or claimed.

## Remaining acceptance gap

This slice does not claim CF-003/CF-004 closure. The family-level authorization consumer switch,
post-cutover forward-recovery proof, and isolated PostgreSQL acceptance remain to be verified.

## Adversarial review of the consumer slice

- The selector/switcher graph was not changed. It is a delegated act-as contract, so replacing its
  identity, assignment, membership, or avatar candidate resolution with owner-only reads would be
  an unapproved authorization-contract change.
- `OrganizationPolicy` was not changed because it explicitly evaluates active membership access;
  treating that relation as owner authority would incorrectly deny delegated/member access and
  would conflate two trust boundaries.
- `AccountPolicy` was selected as an owner-specific consumer. Before the family marker it retains
  the legacy behavior for staged deployment. After the marker it fail-closes unless the explicit
  ownership row, configured principal eligibility, and active resource lifecycle all agree. A
  legacy identity binding cannot grant access after the marker.
- The marker remains the only transition point. No code path was added to roll back from new
  authority to legacy authority after a consumer read, and no automatic owner transfer or recovery
  route was invented. Forward-recovery semantics and isolated concurrency/runtime proof remain
  acceptance gaps.
- A review of the new query test found that its first draft attempted two `ClientIdentity` rows for
  one principal even though `source_record_id` is unique. The fixture was corrected to use a
  separate unowned principal; the production query and its cross-owner assertion are unchanged.
