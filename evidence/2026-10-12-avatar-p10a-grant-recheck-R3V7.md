# P10a Grant authority recheck

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty at the start of this check. Existing staged, unstaged and
untracked changes were preserved. No reset, clean, stash, worktree, push, production operation or
shared database operation was used. The test used the run-owned manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, the primary PostgreSQL host and four workers.

## Focused Grant and transfer-authority collection

The collection covered concrete Enterprise Persona and Bureau Agent Grant issuance, ownership
generation binding, non-owner/member refusal, revocation, permission resolution, Group membership
authorization, transfer reservation cardinality and replay, and the app/org public transport
guards that keep registry admission behind the verified Avatar cutover marker.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from tmp/acceptance-isolated-20261010p8b-primary.json>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test \
  test/services/avatar_access_grants_test.rb \
  test/resolvers/avatar_permission_resolver_test.rb \
  test/policies/group_avatar_membership_policy_test.rb \
  test/services/group_avatar_memberships_test.rb \
  test/operations/avatar_ownership_transfers_test.rb \
  test/models/avatar_transfer_reservation_test.rb \
  test/controllers/base/app/avatar_ownership_transfers_controller_test.rb \
  test/controllers/base/org/avatar_ownership_transfers_controller_test.rb
```

Observed result: `81 runs, 355 assertions, 0 failures, 0 errors, 0 skips` in 5.616 seconds.
A read-only PostgreSQL follow-up reported zero run-owned worker databases and zero active
sessions.

This recheck supports the independently executable P10a Grant/permission and registry-guard
subconditions in the current dirty worktree. It does not establish the O1→O2→O1 full transfer
cutover, P10b Group account semantics, writer quiescence, the P12b marker or any production/shared
data transition. Registry operation tests remain implementation tests until the cutover boundary
is verified.
