# Title validation error rendering

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; uncommitted remediation/locales/tests
  affected results. Unrelated configuration/dump changes retained.
- `run_isolated_tests.py title-errors-red ... -n '/renders title rejection/'`: exit 1, six
  tests/twelve assertions, six expected MissingTranslationData errors. No skipped test.
- Final `run_isolated_tests.py title-errors-final-scoped-green ...`: exit 0, **83 tests/975
  assertions**, zero failures/errors/skips. Covers all six concrete models, both languages,
  missing/empty/malformed/too-long title errors, real normal saves, projected saves, membership
  graphs and step-up nullable evidence.
- Scope: explicit activerecord.attributes title keys for
  agent/bureau/client_persona/company/enterprise/individual in exactly the four canonical bundles.
  YAML parse inspection confirmed all six scoped labels in each bundle. An initial generic-label
  draft was narrowed; intermediate script-layout stops are not claimed as final evidence.
- No validation/deletion/authentication/DB-schema behavior changed. Six new tests support the error
  contract; this is not an additional database_consistency finding removed. Final checker
  verification remains pending at record creation.
- Logs/exit receipts in ignored `tmp/database-consistency-20261019/title-errors-*`; cycle C8 and
  live finding ledger retained in the remediation spec.

- Completed default checker: exit 1, empty stderr, 2,065 displayed groups. Raw 18,317 OK / 2,123
  failures / one warning, identical non-OK identities to the prior accepted state; exact same 873
  model targets/checkers. No violation reduction claimed. Test file RuboCop clean; git diff --check
  clean.
