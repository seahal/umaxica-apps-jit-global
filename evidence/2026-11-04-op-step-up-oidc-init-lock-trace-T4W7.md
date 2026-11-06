# OIDC authorization initiation lock-order trace

- Date: 2026-11-04
- Commit: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively modified and uncommitted; this source review and documentation update were
  performed in that state.
- Scope: APP/ORG Visa authorization initiation through OIDC parent creation/reuse and Base admission
  handoff.

## Observation

`OidcAuthorizationTransactionCoordinator.issue_with_handoff!` calls
`SignUpEmailPendingGuard.with_lock(model_class: model)`. The guard opens a transaction on the OP
model connection and holds its PostgreSQL advisory lock for the block. `matching_admission_parent`
can then lock the OIDC authorization parent. `BaseAuthAdmissionCoordinator.issue_handoff!` locks
that parent and the admission binding in the same OP database transaction. `validate_base_token!`
checks only that the supplied token is the expected realm-specific class. The direct issuance path
does not resolve or lock the Client / Operator principal.

This yields an OP-parent → OP-binding order for this method. It is not a demonstrated
OP-to-principal reverse edge under O-10's principal-lock boundary. Caller-held locks, callbacks, and
exceptional paths are not established by this source trace. The lock inventory now records that
limit. The reproducible lexical scan still has 88 candidate files, of which 9 are named by full path
and 79 are not.

## Commands and verification

- Inspected `app/services/oidc_authorization_transaction_coordinator.rb`,
  `app/services/base_auth_admission_coordinator.rb`, `app/services/sign_up_email_pending_guard.rb`,
  and the APP/ORG Visa authorization controllers with `sed`/`rg`.
- Re-ran the documented two-pattern `rg -l` intersection: 88 candidate files.
- Compared exact candidate paths against
  `specs/op-mediated-step-up/contracts/lock-order-inventory.md`: 9 named, 79 not named by full path.
- No tests, database reads/writes, or runtime operations were performed.

## five.md review

Rechecked C0/C4/C5/C9. The closed C4-18 rename, C5.1 no-persistence scaffold, and C13
synchronization fix are already implemented. Remaining C5 decisions still gate feature code and
persistent/API shape. Repairing the current dirty Chronicle/app_zenith structure dumps or rebuilding
databases is outside the approved scope. No five.md feature code or data shape changed. Reviewed
snapshot SHA-256: `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`.
