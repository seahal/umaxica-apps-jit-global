# rails-support: per-definition ledger

5 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/support/parallel_test_database_cloner_test.rb`

[test/support/parallel_test_database_cloner_test.rb](../../../test/support/parallel_test_database_cloner_test.rb); SHA-256: `b55c2793286eab456e2b6d86b2bf364b7552063478d05b121322828e11d4d4df`.

File-level implementation candidates (including setup/import context): unresolved by static constant/import matching.

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-12805"></a>T-12805 / [7](../../../test/support/parallel_test_database_cloner_test.rb#L7) | "clone_task rebuilds a missing clone"<br>Owner: `ParallelTestDatabaseClonerTest` | `assert_equal(` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-12806"></a>T-12806 / [26](../../../test/support/parallel_test_database_cloner_test.rb#L26) | "clone_task rebuilds an existing clone whose stamped sha differs"<br>Owner: `ParallelTestDatabaseClonerTest` | `assert task`; `assert task.fetch(:clone_exists)` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-12807"></a>T-12807 / [43](../../../test/support/parallel_test_database_cloner_test.rb#L43) | "clone_task skips a clone whose stamped sha matches"<br>Owner: `ParallelTestDatabaseClonerTest` | `assert_nil ParallelTestDatabaseCloner.clone_task(` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-12808"></a>T-12808 / [57](../../../test/support/parallel_test_database_cloner_test.rb#L57) | "clone_task rebuilds every run when the schema dump sha is unavailable"<br>Owner: `ParallelTestDatabaseClonerTest` | `assert task`; `assert_nil task.fetch(:sha)` | unresolved | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-12809"></a>T-12809 / [74](../../../test/support/parallel_test_database_cloner_test.rb#L74) | "run_clone_tasks serializes clones sharing a template source"<br>Owner: `ParallelTestDatabaseClonerTest` | `assert_not overlap, "clones from the same template source must not run concurrently"`; `assert_equal %w(a_0 a_1 b_0).sort, order.sort` | unresolved | S: static inventory; individual semantic review open | stubbed-boundary |
