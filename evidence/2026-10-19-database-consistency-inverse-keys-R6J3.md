# Token reference inverse keys and corrected baseline accounting

Date: 2026-10-19 UTC. Application HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`. Uncommitted
changes affecting results: three token reference models and their three test files. The remediation
specification, ledger and this evidence were also uncommitted. Preexisting `DESIGN.md` and
diagnostic/evidence files were preserved; no commits, resets or migrations ran.

## Correction to baseline summary

This supplements [M8K2](2026-10-19-database-consistency-baseline-M8K2.md). Its 2,119 count is the
number of displayed CLI failure groups, **not individual failures**. Inspecting the actual
`Writers::SimpleWriter` showed grouping by writer unique_key before output. The line suffix
`Total grouped offenses: N` accounts for 58 additional reports.

Read-only `DatabaseConsistency::Processors.reports(Configuration.new)` execution with the same full
default scope returned **2,177 fails, 18,212 OK, one warning** on the original application models.
Counts that differ from the display: MissingIndex **60**, MissingDependentDestroy **233**,
ForeignKey **27**; the other checker counts in M8K2 are unchanged. The one warning is
LengthConstraint on Client.public_id, omitted by the default CLI writer. The ledger now contains all
**2,178** non-OK reports with model/connection identity rather than 2,119 grouped rows.

The three application files modified in this cycle were temporarily restored to their exact HEAD
contents for the original-state raw capture, then restored byte-for-byte to this cycle's changes in
a `finally` block. No other files were replaced. The direct report export does not use the gem's
ReportBuilder#to_h because it emits values as keys; it serializes existing report fields for
inspection without modifying checkers or suppression settings. Raw captures contain no business row
values or credentials.

## Change and TDD

Models: ClientTokenKind (op_base_app), OperatorTokenKind and OperatorTokenStatus (op_base_org). The
inferred inverse keys referred to nonexistent columns. Child belongs_to and real FK/index metadata
already used user_token_kind_id, staff_token_kind_id and staff_token_status_id. The repair makes
those keys and their existing inverse names explicit; all three parent associations retain
restrict_with_error. No DB schema or token issuance/state change occurred.

Nine tests were added to the three existing model test files: loaded association with matching and
empty fixtures; model-side deletion refusal retaining parent/child; direct DB deletion refusal
inside a savepoint retaining parent/child. These exercise actual tables and constraints, with no new
session issuance, behavior mocks or private-method access.

| Stage                                                          | Result                                                                                                                                       |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Existing characterization slice                                | 63 runs, 190 assertions, 0 failures/errors/skips                                                                                             |
| First test draft                                               | 19 runs, 24 assertions, 3 failures/6 errors; corrected strict-loading setup and actual PostgreSQL exception expectation before assessing Red |
| Corrected Red, original models                                 | 19 runs, 39 assertions, 0 failures/6 errors/0 skips; six missing-column query errors                                                         |
| Final Green plus ClientToken/OperatorToken and public-ID slice | 154 runs, 500 assertions, 0 failures/errors/skips, exit 0                                                                                    |
| RuboCop on six changed Ruby files                              | 6 files inspected, no offenses, exit 0                                                                                                       |
| `git diff --check`                                             | exit 0                                                                                                                                       |

Commands used the existing `.env.container.devcontainer` prepare-list value in the test child
process and `PARALLEL_WORKERS=1`, as documented in M8K2. The narrow command was `bin/rails test`
with the three reference-model files; the final command also selected
`test/models/client_token_test.rb`, `test/models/operator_token_test.rb`,
`test/lib/public_id_generation_test.rb` and `test/models/public_id_capacity_contract_test.rb`. Logs
and exit receipts are in the ignored local `tmp/database-consistency-20261019/` directory.

## Full recheck

`bundle exec database_consistency`: exit 1, **2,113 displayed failure groups**, no internal errors.
Raw after-capture: **2,171 fails, 18,221 OK, one warning**, diagnostic process exit 0. Only six
failure identities disappeared; none appeared: three ForeignKeyType and three MissingIndex reports
for the repaired associations. One root cause family, three model changes, zero migrations and nine
added tests. Default full check remains failing; remediation is not complete.

| Artifact under tmp/database-consistency-20261019/ | SHA-256                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| raw-baseline-fixed.json                           | `536129dc2668607421e415f636d8e060ed7118cff4a97b34a1966f2d8451d5d6` |
| raw-after-fixed.json                              | `a4417355d652c0d10dd050a5f1b0cb3d9f49d67d36ba987ff2b3442ab4bd27bc` |
| inverse-after.stdout                              | `99c9a14cb82736b78502ca2808328c56016a73e593af9e951915aa74c924dfc4` |

## Risk and remaining verification

The corrected restriction lookup uses existing FK indexes; no uniqueness validation or new SELECT
was added to saves. Database RESTRICT remains unchanged. No cascade, data conversion, audit loss,
production write or external operation was introduced. Existing public association names and child
columns remain unchanged. UndefinedColumn at the broken read/destroy boundary is replaced by the
intended query/restriction behavior. No query-performance benchmark was needed for the unchanged
indexed equality lookup.

Full Rails suite, clean-fleet reconstruction, production data and production migration prerequisites
were not verified. The remaining 2,171 failures and one warning remain open in the ledger. Local
public-ID lengths do not authorize narrowing model capacity or assuming production readiness.
