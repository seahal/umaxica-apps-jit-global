# Approved owner and regional RP pre-deployment review

Date: 2026-09-23
Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: already had uncommitted changes before this review; no unrelated changes were reset or discarded.

## Scope

This review rechecked the approved CF-003/CF-004 and CF-007 decisions before continuing
pre-deployment implementation. Production data, provider systems, AWS, Cloudflare, deployed
callers, and external Base registration were not accessed or changed.

## Adversarial findings

### CF-003/CF-004

- The six explicit ownership relations and their surface-local principal/resource pairs are
  present in the repository migration and inventory contract.
- The six concrete resource models (`ClientPersona`, `Enterprise`, `Individual`, `Company`,
  `Agent`, and `Bureau`) do not currently expose a persisted lifecycle state or an equivalent
  `lifecycle_active?` contract. Their tables contain no lifecycle column. Principal lifecycle
  state cannot be reused as resource lifecycle state.
- Authorization consumers have not been switched family-by-family to the new relations. The
  cutover guard therefore correctly remains fail-closed.
- No lifecycle column, status enum, cutover marker, or consumer switch was invented in this
  review. Doing so would choose an unapproved persisted shape and would make inactive/retained
  resources appear active.

Disposition: `OPEN — IMPLEMENTATION REQUIRED`. The reviewed owner mapping and backfill boundary
are implemented, but lifecycle authority and family cutover remain incomplete.

### CF-007

- The approved 13-cell matrix and independent logical key namespaces are present as a repository
  contract.
- Core JP/US URI sources and the existing canonical Side JP host can be derived without Host
  header inference.
- No canonical independent Side US host source exists in the repository.
- The active registry still contains the compatibility seven-client set and `core-next-rp`; it
  does not contain the regional cells.
- No unique regional audience source exists. Existing audience values belong to the compatibility
  registrations and cannot be copied or derived into JP/US regional audiences without violating
  the approved isolation decision.

Disposition: `OPEN — CONTRACT CONTRADICTION`. The logical matrix is approved, but the repository
has no authoritative values for two required binding dimensions. No regional registration was
activated.

## Verification performed

- `config/credentials/test.key` was checked for presence only; its contents were not displayed.
- After selecting `.env.devcontainer.example`, all required PostgreSQL/Valkey variables were
  present by name-only inspection.
- The required preflight was attempted:
  `bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'`
- Preflight failed before Rails boot because `primary` could not be resolved:
  `PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution`.
  `primary` and `valkey-kvs` also produced no `getent hosts` result in this process.
- Rails focused tests and the full suite were not run after this failed preflight. No test was
  deleted, skipped, mocked, or weakened to bypass the environment failure.
- Ruby syntax checks passed for the owner inventory, backfill operation, cutover guard, regional
  matrix, and their focused tests.
- Targeted RuboCop passed for those eight Ruby files; `git diff --check` passed.

## Result

The approved authority semantics and regional matrix are documented in the relevant ADRs and
Frozen Plan. The fail-closed implementation boundaries remain in place. Further progress requires
an approved lifecycle data shape for the six resource families and canonical repository sources
for regional audience and Side US host values; those values must not be guessed.
