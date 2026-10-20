# Publishing ordered taxonomy positions

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; uncommitted model, locale, test and
  documentation changes affected these results. Other configuration/dump changes were preserved.
- Tested against manifest-verified isolated database parents and newly receipt-owned two-worker
  clones. No parent schema changes in this slice.
- `run_isolated_tests.py position-red ...`: 60 tests/780 assertions, 24 expected regression
  failures.
- Before-change original-model characterization: 12 tests/540 assertions passed, confirming false
  normalizes to zero. Corrected only the new draft expectation; kept native conversion and existing
  tests.
- `run_isolated_tests.py position-green-preserved-coercion ...`: 255 tests/4,587 assertions, zero
  failures/errors/skips. Includes all twelve ordered families, range/sentinel handling, DB
  constraint exceptions, promotion and immutable snapshot refusal.
- `run_isolated_command.py position-after bundle exec database_consistency`: exit 1, no internal
  error, 2,065 displayed failure groups. Default raw capture: 18,317 OK / 2,123 failures / one
  warning; 24 position NullConstraint reports removed, no new reports. Same 873 application model
  targets.
- Raw logs, commands and inventories retained in ignored `tmp/database-consistency-20261019/`;
  stable finding identities and cause mapping retained in
  `specs/database-consistency-remediation/findings.md`.
- No DDL, additional uniqueness SELECT, trigger or deletion introduced. Whole-suite success and
  production migration applicability are not established by this focused result.
