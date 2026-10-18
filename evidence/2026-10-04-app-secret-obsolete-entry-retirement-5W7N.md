# app Secret obsolete entry retirement

Executed on 2026-10-04 UTC; final observation at 02:11 UTC against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. There were 303 dirty paths
before this record, including concurrent agent changes. Used only the guarded
`codex_integrity_20261003secret_*` disposable fleet.

Removed the unconnected ClientEmergencySecretCredentialSignInOperation and its
old Emergency tests, including its independent caller-supplied session creation,
temporary-access discriminator, five-failure counter and consumed_at updates.
The existing app Emergency GET/POST route remains absent. No replacement session
issuer or compatibility entry was introduced.

Removed the old app create/update/destroy services and their obsolete service
tests. They implemented enabled/status changes, raw-value replacement and direct
Chronicle transactions for the retired schema. The only production create caller
was an app branch in SignSettingsSecretCredentialRegistration; no controller
includes that concern on app. Removed that branch while preserving the com/org
service calls. Production-source searches found no remaining reference to the
removed class names or legacy inventory task.

The security invariant retains the MFA/email transition requirements; its old
requirement on the deleted app destroy service is removed with that API. Existing
name and retirement operations have separate public authorization/transaction
tests. The old final-committer test used fake app success and helper-driven app
bindings despite the implementation already supporting only com/org. Replaced it
with public app/unknown-surface refusal and real com/org malformed-result refusal,
without mocking commit success. This does not claim a complete com/org ceremony.
Their production final-committer implementation was not changed.

Removed the old LOGIN inventory Rake task. Updated the old remaining-work ledger
to supersede its app conversion/revocation-campaign item, retaining historical
observations. Updated the Emergency ADR and app Secret reference to distinguish
source retirement from incomplete persistence and replacement workflows.

Actual verification:

- `bundle exec ruby /tmp/umaxica-secret-db-task.rb test` with app Emergency
  retirement, credential-security invariant, Visitor create service, manual
  reservation/name/retirement operations and the revised final-committer tests:
  **41 tests, 608 assertions, no failures/errors/skips**. The first revised
  final-committer run used nonexistent Visitor/Token fixture names; corrected
  to the actual Visitor fixture and an explicit synthetic invalid-proof session
  reference. This was test setup, not product Red.
- Same wrapper with Operator/Visitor credential models, Visitor create service
  and the revised final committer: **22 tests, 78 assertions, no failures/errors/skips**.
  These selections overlap and their counts are not a combined unique-test total.
- `bundle exec rubocop` on the shared registration concern, credential-security
  invariant and final-committer test: PASS, three files, no offenses after
  formatting. No skip, exclusion or threshold change.
- `bundle exec ruby /tmp/umaxica-secret-db-task.rb --tasks secret_credentials`:
  exit 0 with no task entries; the retired task is not listed.
- Guarded `runner` read of AppTicketRecord's data_source_exists? for
  client_emergency_sign_in_operations: **true**. Its old table/model still need
  scoped persistence cleanup; no DROP was attempted in this slice.
- `git diff --check`: PASS before this record.

Old app kind/status/recovery/withdrawal references still exist elsewhere. Complete
new delivery, Passkey integration, claim/login, Chronicle and audited purge remain
unfinished. No full suite, real browser, complete org Emergency journey or global
com/org regression is claimed. No schema, credentials, shared database, history,
external service, push or deployment was modified here.
