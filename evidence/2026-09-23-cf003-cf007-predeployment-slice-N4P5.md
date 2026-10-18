# CF-003/CF-004 and CF-007 pre-deployment implementation slice

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: uncommitted and contained 228 changed/untracked paths before this record; unrelated
  changes were preserved.
- External activity: no production, provider, AWS, Cloudflare, or GitHub write.

## Scope

This record covers the approved pre-deployment decisions and the repository-only implementation
slice. It does not claim production data inventory, live authority cutover, Base registration, real
key fingerprints, deployed-caller migration, or external retirement.

## Implemented slice

- `AuthorityOwnerMigrationInventory` now exposes the explicit six-resource ownership configuration
  and reports an existing explicit ownership relation as authoritative without treating legacy
  membership as ownership.
- `AuthorityOwnerDirectBindingBackfillOperation` applies only an unambiguous active direct identity
  binding, uses the surface-local authority lock and row locks, is idempotent, and rejects a
  conflicting explicit owner. Membership-based resources remain manual-review; lifecycle and
  family-level cutover are not enabled by this operation.
- `AuthBoundaryAuthorityMap` records the approved 12 regional Core/Side IDs plus global `edit-org`
  as a pre-deployment target. The active seven-client registry remains unchanged during
  expand-and-contract migration; exact regional URI/audience/caller/key binding is not yet active.
- The Frozen Plan, owner-authority architecture documentation, and relevant ADRs now record the
  approved owner mapping, lifecycle/conflict dispositions, cutover point of no return, regional
  matrix, and later deployment gates.

## Adversarial findings

- Owner backfill initially passed model objects into FK columns. The focused test exposed the
  validation failure; the operation now writes the locked integer IDs and the test passes.
- The six resource tables do not yet expose the approved resource lifecycle state, so the operation
  cannot prove resource eligibility. This remains an implementation gate.
- Existing selector/bootstrap/policy consumers still read legacy membership/assignment paths.
  Family-wide cutover and the point-of-no-return cannot be claimed.
- The repository has a Core JP/US root URL registry, but the current Side configuration does not
  provide a complete independent JP/US URI matrix. No missing Side URI, audience, key, registry
  entry, or caller mapping was invented.
- Current OIDC audience semantics and the legacy Core RP bridge are distinct contracts. They remain
  unchanged until the regional registry and caller/session binding slice supplies explicit mapping.

## Verification

The first non-escalated process could not resolve `primary` or `valkey-kvs`; no application or
configuration workaround was used. In the reachable Compose network, `getent hosts primary` and
`getent hosts valkey-kvs` succeeded, and the Rails test process reported PostgreSQL 17.7.

Commands were run with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`, the
approved test database preparation list, and `PARALLEL_WORKERS=1` for focused runs:

- Targeted RuboCop for the changed Ruby files: passed, 5 files, no offenses.
- Ruby syntax checks for the changed Ruby files: passed.
- Focused authority/inventory/target-matrix tests: `18 runs, 198 assertions, 0 failures, 0 errors,
  0 skips`.
- Related authority schema/lock/creator/policy/inventory tests: `64 runs, 588 assertions, 0
  failures, 0 errors, 0 skips`.
- Full Rails suite: `11,585 runs, 73,679 assertions, 0 failures, 0 errors, 8 skips`.
- `git diff --check`: passed.

Skipped tests were existing suite skips; none were added for this slice. The full suite result proves
repository regression health only and does not close the remaining CF-003/CF-004 or CF-007 gates.

## Current blocker decision

- `CF-003/CF-004`: `OPEN — IMPLEMENTATION REQUIRED` — direct-binding backfill is covered, but
  lifecycle representation, all-family mapping/backfill evidence, consumer cutover, and
  forward-recovery after the point of no return are incomplete.
- `CF-007`: `OPEN — IMPLEMENTATION REQUIRED` — the approved 13-cell logical target is recorded and
  tested, but active regional registry entries, exact URI/audience bindings, caller migration,
  RP-session binding, and `core-next-rp` retirement procedure are incomplete. Missing external
  deployment facts remain later gates.
