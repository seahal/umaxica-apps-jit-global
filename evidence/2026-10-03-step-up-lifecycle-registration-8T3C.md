# Step-up lifecycle and registration foundation

On 2026-10-03, against commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with
uncommitted implementation and concurrent unrelated changes:

- Cancellation, credential transition, token status and refresh concern tests passed:
  **40 tests, 216 assertions**. New public token-revocation and refresh tests first failed because
  pending transactions remained pending, then passed after connecting model-owned revocation.
- Client/Visitor/Operator token models and issuance/cooldown surface tests passed:
  **147 tests, 498 assertions**.
- Admission coordinator, Auth ceremony models, opaque store, cancellation and credential transition
  tests passed: **68 tests, 385 assertions**, including registration/bootstrap purpose isolation.
- The broader 154-test run including `root_login_establishment_flow_test.rb` failed:
  **one failure, four errors**. That integration file still enters Auth without Base admission and
  expects issuance/limit management there; it requires an actual Base-to-Auth-to-Base journey.
  The failure was not hidden by restoring Auth root issuance.
- Generated registration FK/admission-purpose migrations applied successfully to test
  `app_ticket`, `com_ticket` and `org_ticket` databases. No development or production migration
  was applied. Pending candidate rollback requires ending/draining unconfirmed records first.
- TOTP enrollment issuance test could not start: concurrent
  `20261003215326_rebuild_app_secret_credentials.rb` was pending. Inspection identified a
  destructive principal rebuild owned by another participant; it was not applied or changed.
- A second enrollment-test attempt remained blocked by that principal migration. The test harness
  applied another participant's new ticket receipt migration during preparation; no application
  tests ran in this attempt. Targeted RuboCop passed for the new enrollment operation/model/test
  and all three registration migrations, and for the amended token authority revocation.

These checks do not prove the entire R01–R16 ledger complete. Enrollment controller connection,
registration confirmation/finalization, selector behavior, browser checks and full regression
remain incomplete. OTP logging remediation remains separately escalated and excluded.
