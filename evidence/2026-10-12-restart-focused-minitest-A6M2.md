# Restart focused Minitest — 2026-10-12

This record captures the first focused public-boundary check after the required Section 5.3, Section
16, and Section 14.2 restart reading. It is execution evidence for the current local tree, not an
independent acceptance decision.

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD during the check: `92f7b93cdd74d3921de562cf103c26be6c0de3cd`
- Worktree: clean before and after the check; no unrelated changes were modified.
- Database scope: the existing run-owned manifest
  `tmp/acceptance-isolated-20261010p8b-primary.json`, all twenty non-replica writer databases, four
  Rails workers, and no shared or production database.

The guarded command used the manifest's host, run ID, absolute manifest path, and twenty database
names before invoking Rails:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the twenty names recorded in the manifest> \
bundle exec rails test \
test/unit/security/observability_span_scrubber_test.rb \
test/unit/security/opentelemetry_initializer_test.rb \
test/operations/avatar_group_concrete_ownership_backfill_operation_test.rb \
test/queries/avatar_group_ownership_transition_inventory_query_test.rb
```

Observed result: `19 runs, 73 assertions, 0 failures, 0 errors, 0 skips`.

A read-only PostgreSQL catalog probe after the run reported zero run-owned worker databases and zero
active sessions. The test used the existing isolated-database harness; no reset, drop, CI, Podman,
production, shared-database, or external-service operation was performed. This check does not close
the remaining operational cutovers, environment-owned runtime checks, unresolved policy decisions,
or the independent acceptance work excluded by the user.
