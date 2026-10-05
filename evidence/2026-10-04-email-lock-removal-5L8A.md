# Email lock and credential removal

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with uncommitted authentication changes affecting the results.

APP and COM inventory previously counted temporarily locked Email OTP as a fallback protecting removal of the last UV-capable Passkey. The new public inventory regression failed before the fix (seed 27380: one test, five assertions, one failure). Inventory now uses its existing writer-clock snapshot to exclude locked Email from removal-compatible methods while retaining its configured, login and contact classifications. At the lock deadline, Email becomes eligible again. No schema or response shape changed.

The boundary test covers one microsecond before, exactly at, and one microsecond after the deadline on both surfaces. Public removal-operation tests also verify refusal preserves credential status, root usability, prior freshness and the Email lock deadline.

Tests ran only against the owned copied databases identified by `tmp/auth-boundary-isolated-20261003auth6f3.json`, using `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261003auth6f3`, `POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket` and `PARALLEL_WORKERS=1`. No database rebuild was performed in this check.

Final command: `bin/rails test test/services/authentication_credential_inventory_common_identity_test.rb test/operations/identity_credential_removal_committer_test.rb test/policies/auth_method_guard_test.rb test/services/auth_method_guard_coverage_test.rb test/operations/identity_step_up_email_verification_committer_test.rb test/operations/identity_step_up_email_code_issuer_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb`.

Result: seed 31434, 48 tests, 484 assertions, zero failures, errors or skips. RuboCop passed for the inventory and the two changed test files; their scoped `git diff --check` passed.

This verifies the Email lock/removal contract, not completion of R01–R16. Browser verification remains user-owned. OTP logging remediation remains excluded by instruction.
