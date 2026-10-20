# Preserve projected saves and nullable evidence

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; uncommitted
  remediation/tests/locale/comments affected results, unrelated configuration/dump changes
  preserved.
- C7 had reduced nine ColumnPresence reports, but additional public projected-title saves failed on
  all six hosts: `projected-title-red`, six tests, six errors, exit 1. Required-title rejection
  rendered through the existing missing title label. Guard removal was not behavior preserving.
- Restored only the five exact task-owned C7 implementation diffs to original declarations with
  concurrent-change guards. Kept tests and explanatory FIXME comments. No existing test removed,
  weaker validator added, checker reordered/configured or schema changed.
- Final `run_isolated_tests.py preserved-projection-and-nullable-final ...`: **344 tests/5,542
  assertions, zero failures/errors/skips**, exit 0. Includes all 203 added tests, all nine projected
  title/name cases, original explicit-invalid input cases, direct DB NULL refusal, six step-up
  nullable-evidence cases and all accepted inverse/sequence/position changes. First preservation
  run's only three failures compared in-memory nanoseconds with stored microseconds; corrected the
  new baseline with reload before capture, preserving exact equality.
- Six scoped changed files passed RuboCop; `git diff --check` clean.
- Default checker `preserved-contract-after`: exit 1, empty stderr, 2,065 displayed failure groups.
  Raw capture: 18,317 OK / 2,123 failures / one warning, no new non-OK identities versus C6.
  Identical 873 application targets and enabled checkers. C7's nine-report reduction is withdrawn;
  accepted baseline reduction is 54 individual failures in three cause families.
- No accepted migration, DDL, production operation, dump overwrite, auth lifecycle change or
  cascade. D5/D6 ask user disposition for eighteen preserved contract conflicts; D4 four-index local
  schema proposal remains awaiting input.
- Full isolated suite before the C7 reversion completed with eight failures/four errors (see F9R2
  evidence). It is not a passing full-suite result, and the final state was verified by the focused
  344-test run rather than another whole-suite run.
- Stable finding ledger and decisions: `specs/database-consistency-remediation/`. Raw logs/receipts
  are retained in ignored `tmp/database-consistency-20261019/`.

- Additional read-only
  `run_isolated_command.py schema-drift-current bin/rails db:verify_no_schema_drift`: terminal exit
  1, reports all 32 configured schema dumps as drifted. The task uses temporary dumps and does not
  overwrite worktree dumps. Its result also includes existing git differences, so it is not a
  per-object drift attribution. Existing empty dumps remain untouched. This check is failed, not
  skipped or passed.
- Comment-only FIXME annotations on the two shared step-up Concerns subsequently passed scoped
  RuboCop (two files, no offenses). No behavioral change followed the passing focused run.
- Final read-only isolated readiness: exit 0; all 32 writer identities verified, no worker DB
  leftovers, no active parent sessions, no pending migrations. Explicitly confirmed the destroyed
  empty generator's version is absent from the Publishing migration registry. This confirms local
  cleanup, not production readiness.
