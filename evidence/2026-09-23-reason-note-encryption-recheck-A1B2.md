# Approved reason-note encryption recheck

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Classification: `ALREADY_SATISFIED`
- Worktree: pre-existing changes were preserved; no key, configuration, schema, external service,
  or production data was changed.

## Current implementation

The approved free-text fields already declare standard Active Record Encryption:

- `Client.admin_locked_reason_note`
- `Visitor.admin_locked_reason_note`
- `Operator.admin_locked_reason_note`
- `AccountAccessEvent.reason_note`
- `AppEnforcementCase.reason_note`
- `ComEnforcementCase.reason_note`
- `OrgEnforcementCase.reason_note`

No deterministic encryption is used for these non-searchable notes, and existing encrypted
identifier/token fields were not changed.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test test/models/sensitive_reason_note_encryption_test.rb
```

Result: `1 run, 28 assertions, 0 failures, 0 errors, 0 skips`.

The test reads each value through Active Record and reads the persisted column through the writing
database connection, asserting that the plaintext marker is not stored. Targeted RuboCop across the
seven models and the test passed with no offenses.

No migration or backfill is required for this already-satisfied target. Persona/Organization name
encryption and broader lifecycle scrubbing remain separate blocked design/data work; this result
does not close those gates.
