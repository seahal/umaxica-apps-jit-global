# Authority family cutover gate correction

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes present; no unrelated changes were reverted.
- External writes: none.

## Finding

The first adversarial review found that `AuthorityOwnerCutoverGuard` treated every resource whose
lifecycle was not `active` as an unresolved owner-authority row. The approved contract requires the
family gate to reject unresolved authority-required active rows; an explicitly inactive,
discarded, deleted, or retained resource may keep historical data while normal authorization is
unavailable.

## Change

The public cutover guard now excludes only those four explicit non-authority-required lifecycle
states from its unresolved set. It still fails closed for an active resource, a missing/unknown
lifecycle state, an ineligible authoritative owner, or a missing authoritative owner on an active
resource. No selector/switcher act-as behavior, owner transfer route, legacy fallback, or automatic
owner promotion was added.

Public regression coverage was updated for inactive and discarded resources. The tests were not
executed because the required PostgreSQL and Valkey service names are unavailable in the current
process; no test was skipped or weakened.

## Verification

- Ruby syntax: passed for changed implementation and test.
- Targeted RuboCop: 8 files, no offenses.
- Brakeman 8.0.6: 0 errors, 0 security warnings.
- `git diff --check`: passed.
- Rails focused/full tests: not run after preflight failed with
  `PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in
  name resolution`.
