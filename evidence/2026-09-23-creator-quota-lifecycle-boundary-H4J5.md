# Creator quota lifecycle boundary

- Date: 2026-09-23
- Repository commit: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were present; this check ran against the current dirty worktree.
- Scope: CF-003/CF-004 pre-deployment owner/lifecycle slice.

## Change

The six concrete creator operations now use their surface-local `AccountQuotaPolicy` or
`OrganizationQuotaPolicy` inside the existing principal lock and writer transaction. Direct counts
of ownership rows were removed. Only an explicitly `active` lifecycle row consumes a quota slot;
an owned resource without a lifecycle row fails closed. The creator still commits the resource,
active lifecycle row, and ownership row atomically.

## TDD coverage

RED tests were added before the creator changes for inactive owned resources and owned resources
without lifecycle rows. Existing quota tests were updated to create the required explicit active
lifecycle rows. Public creator behavior is covered; no private method is called directly.

## Verification

- Ruby syntax checks for the six creators and the two changed creator tests: passed.
- Targeted RuboCop for the six creators, two quota policies, and changed tests: passed (`10 files
  inspected, no offenses detected`).
- `git diff --check` for the changed slice: passed.
- Focused Rails test command with the required devcontainer environment and
  `PARALLEL_WORKERS=1`: not executed to assertions. Rails schema boot stopped because the current
  process could not resolve PostgreSQL host `primary` (`PG::ConnectionBad: could not translate host
  name "primary" to address: Temporary failure in name resolution`). No localhost substitution or
  configuration change was made.

## Boundary

This closes the creator/policy quota discrepancy only. It does not switch selector/switcher act-as
resolution, perform a family-wide authorization cutover, or close CF-003/CF-004.
