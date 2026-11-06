# OIDC authorization purge lock-order source trace

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; inspected source files were in the existing worktree.
- Scope: trace the OIDC authorization purge's direct and indirect row locks for O-10 inventory.
- Evidence inspected: `app/operations/oidc_authorization_transaction_purger.rb`,
  `app/operations/auth_admission_binding_purger.rb`,
  `app/models/concerns/oidc_authorization_transactionable.rb`,
  `app/models/client_oidc_authorization_transaction.rb`, and callback declarations on the admission
  binding models.
- Finding: the purge locks authorization, session-limit resolution, and flow rows in OP; its Zenith
  Secret-reference lookup is a `pluck` without row locking. The admission purger locks Auth parent,
  binding, and ceremony-session rows and removes eligible terminal signup flows with `delete_all`.
  No Client/Operator row lock or principal-locking callback was found in these direct purge paths.
- Limit: this does not prove that indirect callers outside the purge job or unrelated callbacks
  cannot hold other locks.
- Verification: source inspection only; no tests or database operations were run.
