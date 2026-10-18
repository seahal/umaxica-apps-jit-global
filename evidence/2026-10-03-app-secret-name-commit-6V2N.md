# app Secret scoped name mutation

Executed on 2026-10-03 at approximately 23:32–23:39 UTC against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with concurrent uncommitted changes.
Only the task-owned `codex_integrity_20261003secret_*` disposable fleet was used.

## Implemented boundary

ClientSecretNameCommitter uses the existing operation-specific StepUpRequirement
and StepUpResolver, with the existing default methods and freshness. It rereads
the current Token from the writer under a row lock; the caller's cached Token
cannot authorize a revoked, restricted or expired session. The actor must be a
persisted Base app Client and the credential must be owned and currently available.
Claimed, revoked, discarded and unconfirmed credentials cannot be changed.

The row-lock order is Client in Zenith, Token in Ticket, then credential in Zenith.
Ticket is read and locked only: its surrounding transaction retains the session
lock until the Zenith mutation finishes. This is not a distributed transaction.
Name mutation and the typed source outbox event share the Zenith transaction.
Secret digests and lifecycle facts are unchanged; the name is absent from audit data.

## Actual execution

The initial public-operation Red was three missing-class errors, after database
preparation succeeded. Initial Green was three tests and 15 assertions. The
operation was then split into private validation and mutation methods to satisfy
existing complexity gates without changing the public interface or gate settings.

Final command:

```text
bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/operations/client_secret_name_committer_test.rb
  test/operations/app_secret_step_up_binding_test.rb
  test/policies/client_secret_credential_policy_test.rb
  test/models/client_secret_audit_outbox_test.rb
```

PASS: 27 tests, 231 assertions, no failures, errors or skips. Covered accepted
Passkey/TOTP freshness, wrong owner, absent freshness, wrong scope/method/session/
purpose/audience, future and expired freshness, session revocation/restriction/
expiry, terminal and unconfirmed credentials, and source rollback. Name boundaries
254/255/256 and nil, empty, whitespace, zero, array, hash, NUL and invalid UTF-8
were exercised through the public operation. Database facts for refusal cases
were persisted in rolled-back test transactions; no successful authorization was
mocked and no private method was invoked.

Two intermediate test-setup issues were corrected: model readonly protection
prevented constructing terminal rows through update_columns, and the test runner
requires assert_nil for nil expectations. Neither is counted as a product Red.
The explicit fixture-state SQL writes remain confined to disposable tests.

Final RuboCop on the operation and its test passed (two files, no offenses).
`git diff --check` passed. No schema, payload format, refresh contract, shared DB,
external setting or deployment changed.

## Limits

The operation is not yet connected to a management HTTP action. These tests
establish persisted Step-Up evidence as setup; they do not complete a real
Secret login or Step-Up ceremony. No browser, CSRF request, concurrency barrier,
Chronicle delivery or complete Secret issuance journey is claimed by this slice.
