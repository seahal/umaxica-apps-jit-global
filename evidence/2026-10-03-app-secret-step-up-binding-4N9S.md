# app Secret Step-Up scope and bootstrap refusal

Executed on 2026-10-03 (UTC), against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted work.
Only the task-owned `codex_integrity_20261003secret_*` disposable fleet was used.

## Finding and change

The app Secret scope still allowed retired settings paths and did not admit the
specified `/secrets` resource namespace. BaseStepUpAdmissionIssuer also allowed a
bootstrap ceremony for that scope when the signed-in Client had no credential
history. These contradict the approved canonical path and no-bootstrap contract.

Changed only APP's existing settings_secret_credential return pattern to `/secrets`
with a path/query/fragment boundary. COM explicitly overrides that entry and ORG
has its own catalog; both retain their existing paths. Added a specific bootstrap
refusal for the app Secret scope to the existing issuer. Other scopes, surfaces,
methods, TTLs, AAL defaults and bindings are unchanged. The accepted precedence ADR
records the scope/path distinction and absence of a bootstrap exemption.

## Actual execution

`bundle exec ruby /tmp/umaxica-secret-db-task.rb test
 test/operations/app_secret_step_up_binding_test.rb`:

- Red: canonical Secret return failed admission; bootstrap and retired settings
  return were accepted when refusal was required (2 failures, 1 error).
- Initial combined Green with existing Base admission/bootstrap operation tests:
  9 tests, 69 assertions, no failures/errors/skips.
- Added a normal Token with established_authentication_method=secret: it can start
  a scope/session-bound Passkey/TOTP ceremony without gaining freshness at start.
  This tests admission, not completion of an actual Secret login or Step-Up.
- Added wrong-session and Secret-as-method refusals with no new transaction rows.
- Added actual COM/ORG public issuer calls: their existing /identity/secrets return
  remains accepted, while app's /secrets/new return is refused.
- Final selection included the new test, Base admission/bootstrap operations,
  Auth step-up admission HTTP tests and Secret ownership policy tests:
  **24 tests, 241 assertions, no failures/errors/skips**.

Tests exercise public operations and persisted ticket transactions, without calling
private methods or mocking successful authorization. Token creation is test setup,
not a new application login issuer. No step-up freshness is established by starting
an admission. Secret management HTTP mutations remain unconnected and must enforce
current session, scope, freshness and ownership before their own source transaction.

RuboCop corrected two layout offenses in the new test. No schema, API payload,
refresh protocol, compatibility route, external configuration or deployment changed.
Final RuboCop inspection passed (3 files, no offenses). `git diff --check` passed.
