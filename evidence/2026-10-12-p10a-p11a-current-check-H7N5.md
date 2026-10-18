# Current P10a and P11a focused verification

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree contained pre-existing staged, unstaged and untracked changes (120 paths at this
check). No reset, clean, stash, worktree, push, production or shared-database operation was used.

Against the run-owned PostgreSQL manifest `tmp/acceptance-isolated-20261010p8b-primary.json`, the
following current public behavior collection was run with four workers:

```text
bundle exec rails test \
  test/services/avatar_access_grants_test.rb \
  test/resolvers/avatar_permission_resolver_test.rb \
  test/policies/group_avatar_membership_policy_test.rb \
  test/services/group_avatar_memberships_test.rb \
  test/models/dead_identifier_history_contract_test.rb \
  test/models/dead_identifier_destroy_test.rb \
  test/lib/identifier_history_fingerprint_verifier_test.rb \
  test/operations/dead_identifier_purge_test.rb \
  test/operations/dead_identifier_purge_concurrency_test.rb \
  test/models/realm_identifier_encryption_test.rb \
  test/models/concerns/public_id_test.rb
```

Result: `124 runs, 857 assertions, 0 failures, 0 errors, 0 skips`.

This confirms the selected current Grant, ownership-access, dead-history, realm-encryption and
public-generation boundaries in the disposable environment. It does not prove P10a/P11a global
completion, the independent COMMIT/serialization matrix, Group account semantics, Avatar cutover,
real-data retention policy or the remaining identifier inventory.
