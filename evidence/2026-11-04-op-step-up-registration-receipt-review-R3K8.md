# O-10 registration source receipt review

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; the inspected schema-dump diffs predated this review and were
  preserved.
- Scope: source review of O-10 passkey registration, TOTP enrollment, current audit receipts and the
  remaining lock-order candidates.
- Sources inspected: `IdentityPasskeyRegistrationFinalCommitter`, `PasskeyRegistrationOperation`,
  `PasskeyAuditOutbox`, `IdentityTotpEnrollmentFinalCommitter`, `ClientTotpCredential`,
  `IdentityAudit`, `RetentionPurgeJob`, the current lock-order inventory and the configured Zenith
  database ownership.
- Result: passkey and TOTP writers take the actor before OP rows but currently commit OP consumption
  before the enclosing Zenith credential transaction. Passkey registration writes an
  operation-referenced outbox row in the source transaction, without uniqueness on registration
  operation references. The TOTP writer has no corresponding receipt and does not call the current
  `totp.enable` activity writer. The existing generated model annotation says `app_principal`, while
  implementation inheritance and configured database ownership place the model under `app_zenith`.
- Worktree observation: `db/app_zenith_structure.sql` is 448 bytes with no `CREATE TABLE`; its
  existing diff removes 9,973 lines. `db/org_zenith_structure.sql` is 262,172 bytes. These are file
  observations only, not live database results. No schema dump was regenerated and no database was
  read or written.
- Design: `specs/op-mediated-step-up/contracts/o10-registration-source-receipts.md` proposes a
  partial unique index for passkey registration receipt references and an additive APP TOTP receipt
  table. It remains unapproved; post-source Auth ceremony expiry recovery and TOTP audit delivery
  require review.
- Verification: source search and document review only. No tests, migrations or database operations
  were run. The narrower lexical screen still has 80 paths not named individually in the inventory,
  so the O-10 lock graph remains incomplete.
