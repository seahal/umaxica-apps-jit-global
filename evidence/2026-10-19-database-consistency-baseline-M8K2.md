# Database consistency baseline

Date: 2026-10-19 UTC. Application commit: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`. The
preexisting worktree modified `DESIGN.md` and had two untracked diagnostic files and
`evidence/2026-10-19-database-consistency-connection-checkout-Q7D4.md`. These were preserved. No
staged changes were present. Branch: `feature`. This record precedes application edits; new
remediation specification/ledger files were uncommitted when recorded.

## Execution and versions

- `bundle exec database_consistency`, default configuration and full target scope, exit **1**. 2,119
  `Checker fail` lines; no `Some checks failed with an error` or internal diagnostic output.
  `No configuration files were provided` is informational; no suppression file was supplied.
- Ruby 4.0.7, Bundler 4.0.23, Rails/ActiveRecord 8.2.0.alpha. Rails locked source revision:
  `72ffadb2073a6f81696f4f6559eb6a7ce70496c7`.
- database_consistency 3.0.16, local fork revision `d5d1781f3d642b428d6a9654099b0cd96ce52fd8`.
  Existing connection API repair was retained.
- Actual PostgreSQL server: `18.6 (Debian 18.6-1.pgdg12+2)` on every inventoried connection.
- First sandboxed invocation exited 1 before inspection because debugger socket binding was denied.
  Its output is separate; it was not counted as a completed check. The subsequent unrestricted
  invocation completed. No application/deprecation/checker configuration was changed.

## Retained local artifacts

Full stdout/stderr and read-only catalog/model inventories are in
`tmp/database-consistency-20261019/` (ignored local artifacts, not committed raw logs).

| File                | SHA-256                                                            |
| ------------------- | ------------------------------------------------------------------ |
| baseline.stdout     | `2ca3c73956586f35b0e0661a50789295b2d116b23005f2c9be728293ac0c6b50` |
| baseline.stderr     | `0deb12a6294fcb50372af2e298c40839401549f4a873a73bddf1d913025d57a8` |
| inventory.json      | `402fc353c3e190af4f139763e20a614a81c407518edb2db264083a22eaa95fc8` |
| test-inventory.json | `20fbf92e6e6e45071f3f4cbe47581df651e59b1e41137eeaadc411476c6000d5` |

## Reconciled findings

| Checker                                     |    Count |
| ------------------------------------------- | -------: |
| UniqueIndex                                 |      608 |
| LengthConstraint: DB shorter than validator |      216 |
| LengthConstraint: missing validator         |      516 |
| NullConstraint                              |      332 |
| MissingDependentDestroy                     |      222 |
| RedundantIndex                              |       85 |
| RedundantUniqueIndex                        |       27 |
| ColumnPresence                              |       33 |
| ForeignKey                                  |       26 |
| ForeignKeyCascade                           |        8 |
| ForeignKeyType                              |        3 |
| MissingIndex                                |       14 |
| ThreeStateBoolean                           |       15 |
| NumericalityConstraint                      |       14 |
| **Total**                                   | **2119** |

All 2,119 lines map to concrete model/connection/table records. Stable per-finding IDs, owning
connections, attributes/FKs/index columns, original messages, provisional cause families, proposed
investigation and test disposition are in
[the ledger](../specs/database-consistency-remediation/findings.md). Hypothesis groups are not
proven independent defects. The 216 public-ID rows share the capacity mismatch; the three
ForeignKeyType rows share convention-derived inverse FKs absent from the real token tables.

## Catalog and tests

Read-only catalog queries used `SET TRANSACTION READ ONLY`. Inventories covered 893 concrete
existing-table models, 30 model-owned development connections and 32 configured test writers. All
inventoried migration contexts reported no pending versions. This does not establish clean migration
reconstruction or equality with committed structure dumps. Actual modeled public-ID columns: 225
varchar(21), 48 unbounded varchar, one varchar(25), one varchar(255), one varchar(16). Observed
nonempty table maxima were 16 or 21; no sampled model table had a larger value. These are local
development aggregate facts, not production data or consumer compatibility verification.

Initial focused test invocation stopped during preparation: inherited
`POSTGRESQL_TEST_PREPARE_DATABASES` included retired ticket database names. Repeated in a child
process using the exact existing `.env.container.devcontainer` list and `PARALLEL_WORKERS=1`. The
catalog and target validation remained enabled; no migration was pending and no reset ran.

`bin/rails test test/lib/public_id_generation_test.rb test/models/public_id_capacity_contract_test.rb test/models/client_token_kind_test.rb test/models/operator_token_kind_test.rb test/models/operator_token_status_test.rb`:
**63 runs, 190 assertions, 0 failures, 0 errors, 0 skips**, exit 0. Full suite, production preflight
and schema reconstruction remain unverified.
