# Concrete required attributes and MediaFile hold

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; uncommitted implementation, locale, tests
  and documentation affected results. Concurrent unrelated configuration/dump work preserved.
- Before refactor: `run_isolated_tests.py organization-persona-characterization-corrected ...`: 67
  tests/563 assertions passing. All seven actual hosts, direct DB null refusal and MediaFile exact
  length included.
- After: `run_isolated_tests.py organization-persona-green ...`: 242 tests/4,736 assertions, zero
  failures/errors/skips, on receipt-owned isolated two-worker databases.
- Seven scoped implementation/test files: RuboCop clean. A subsequent formatting-only cleanup is
  included in the pending whole-suite run.
- Default checker `organization-persona-after`: exit 1, no internal error; 2,056 displayed failure
  groups. Raw `organization-persona-raw-after`: 18,326 OK / 2,114 failures / one warning. Exactly
  nine ColumnPresence findings removed; no additions. Exact same 873 targets and enabled checkers.
- MediaFile Red revealed overlooked `chk_media_files_pid` requiring exactly 21 characters in the
  real DB, historical dump and migration support. Capacity-only proposal stopped; user explicitly
  chose preserve and hold. Empty generated migration registration was reverted through its owning
  migration context before destroying the unused generator artifact. No DDL, data rewrite or dump
  generation. Three passing characterizations retain generation, exact-length and NOT NULL/UNIQUE
  requirements.
- Logs retained under ignored `tmp/database-consistency-20261019/`. Decisions, cycle descriptions
  and stable per-finding ledger retained under `specs/database-consistency-remediation/`. No claim
  of whole-suite success or production applicability.

Later compatibility correction: six additional projected-title saves failed with C7. The five C7
model/Concern edits were restored to their exact original declarations, preserving unrelated work.
The nine-report reduction above is historical and is **not an accepted remediation result**. See
cycles.md C7 correction; post-reversion tests and checker capture are separate pending results.
