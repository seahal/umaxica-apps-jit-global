# Owned parallel worker database lifecycle

HEAD: `b73e2e1213b6d52d6290f5f960d6cd125a8f6626`, feature. The database-safety adapter, existing
parallel cloner, fleet rebuild command and prior application/test/migration/generated-schema work
are uncommitted alongside unrelated source-policy/OTP documentation. Documentation persistence is
not a reproducible implementation snapshot. All database execution used owned run 20261010p3d2,
primary, twenty verified parent catalogs and freshly created synthetic worker copies. No shared,
production, remote or CI operations occurred.

The old isolated guard required one worker. Its ordinary clone path could force-drop existing names
without run-owned OID receipts. The new isolated path creates fresh worker databases from normally
migrated parents, records private actual identities, verifies targets before forked connection use,
and cleans only matching inactive worker objects in the parent. It refuses existing names, non-test
admission, wrong worker binding, changed OIDs and active connections. Receipt updates use Rails'
existing File.atomic_write; normal fixtures, migrations, constraints and triggers remain.

Rails runs Minitest through at_exit. An unlock registered during test-helper loading would execute
before the suite; inherited LOCK_UN could also release the parent's lock. The existing process-lock
descriptor now lives until process exit. The rebuild command shares that lock in a block
encompassing its complete lifecycle and refuses an active run before boot/catalog/mutation. No
test_helper.rb, application role authority, database business policy or production configuration was
changed.

## Actual observations

- Direct isolated runner, two workers: forty actual clone OIDs verified; parent configurations
  explicitly compared and unchanged. Reprovisioning existing names refused; wrong worker binding,
  wrong connection receipt OID and wrong cleanup OID refused. An active synthetic clone connection
  refused cleanup without termination. Parent exit removed only its forty objects.
- Final direct runner additionally exercised three non-test admission values by temporarily setting
  Rails.env in this already test-configured process; each refused before DB access. This was not a
  development/production boot or live environment verification. The real two-worker construction
  then passed with atomic receipt persistence, exit 0.
- Initial four-process local regression: 94 runs, 535 assertions, zero failures/errors/skips,
  5.207638 seconds. Its four worker receipts recorded twenty objects each and cleanup completion.
- First four-process full suite: 15,033 runs, 127,496 assertions, one failure, zero errors/skips,
  347.635941 seconds, exit 1. PrimaryDatabaseOwnershipTest expected primary but observed publishing
  in worker 2. It was not dismissed as an old failure or hidden by changing the test. Gate 3 halted
  new feature work.
- Actual installed Rails find_db_config selected the first YAML entry for nil configuration. The old
  after-fork establish_connection call was nil; publishing is first. The fix explicitly uses
  establish_connection(:primary), preserving ApplicationRecord's current ownership contract.
- Final eight-file four-process local regression including the unchanged primary ownership test: 98
  runs, 556 assertions, zero failures/errors/skips, 6.257711 seconds. Files are the prior ORG
  Telephone seven-file regression plus test/tooling/primary_database_ownership_test.rb.
- Post-local read-only catalog check found all eighty planned worker names absent and compared the
  parent's twenty full OID/owner/comment rows to the manifest unchanged, exit 0.
- Scoped RuboCop passed the three modified environment files, zero offenses; git diff --check
  succeeded. No environment-construction Minitest/Vitest case was added.
- Idle rebuild verify-only: exit 0, twenty databases and twelve scoped HMAC roles verified.
- During the actual four-process suite, a separate nonblocking flock failed to acquire its run lock
  as expected. During the final recovery suite, rebuild verify-only exited 1 with
  `isolated test run is active; rebuild refused`, before boot/catalog/drop. This is an expected
  safety refusal, not a successful rebuild or a test failure.

The first Gate 3 recovery Vitest exited 0: 99 files, 1,140 tests, 18.62 seconds. Rails finished with
15,033 runs, 127,498 assertions, one failure, zero errors/skips, 362.399215 seconds. The unchanged
forbidden-pattern guard rejected a newly added Rails.env.test? branch in lib. This was a new
regression, not a successful gate. No subsequent feature work started.

The correction keeps runtime admission in the test-support cloner and makes DatabaseSafety check
nonempty, explicitly test-owned connection configurations independently of runtime branching. No
invariant test, exclusion or allowlist was changed. Focused forbidden-pattern and primary ownership
tests passed: 9 runs, 30 assertions, zero failures/errors/skips, 0.804417 seconds. Final direct
construction and renewed full Gate 3 verification remain pending; no Green or final acceptance is
claimed. Real Avatar COMMIT/RC/RR/Serializable behavior, interrupted-creation recovery, schema
dump/restore, host mounts and full nine.md acceptance remain separate, incomplete checks. No
application/test/migration/schema commit or push occurred.

## Command references

Commands used the explicit verified run/manifest, complete preparation list and test environment
from the operational procedure; secret values were neither printed nor recorded. Ordinary suite runs
used `PARALLEL_WORKERS=4`; direct clone construction used two workers.

- `bundle exec rails test` (full runs; outcomes above).
- `bun run test` (full Vitest runs; outcomes above).
- `bundle exec rails test test/unit/security/forbidden_rails_patterns_test.rb test/tooling/primary_database_ownership_test.rb`
  (9 runs, 30 assertions, zero failures/errors/skips).
- `bundle exec rails runner /tmp/isolated-worker-clone-direct-20261011.rb` (actual fresh clone
  construction and safety refusals, final exit 0). This session-local script is not a durable test
  reference or new verification runner. Reproduce with the owning operational procedure.
- `bundle exec rails runner /tmp/worker-configuration-admission-20261011.rb` (empty and
  development-owned configuration sets refused before receipt/DB access, exit 0).
- `bundle exec rubocop lib/umaxica/test_environment/database_safety.rb test/support/parallel_test_database_cloner.rb scripts/postgresql-rebuild-isolated-test-fleet`
  (3 files, zero offenses).
- `bundle exec scripts/check-repository-knowledge docs/operations/db-workflow.md specs/integrated-stack-delivery/acceptance.md evidence/2026-10-11-owned-parallel-clone-lifecycle-H7N2.md`
  (8 Skills/adapters, 69 documents, 1 evidence record; exit 0).
- `git diff --check` (exit 0).
