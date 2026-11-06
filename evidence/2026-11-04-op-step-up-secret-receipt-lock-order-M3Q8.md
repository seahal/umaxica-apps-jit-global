# Secret sign-in receipt lock-order source trace

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; source files inspected were part of the existing worktree.
- Scope: trace the production creation path and model callback for `ClientSecretSignInReceipt` as
  one O-10 candidate in `specs/op-mediated-step-up/contracts/lock-order-inventory.md`.
- Evidence inspected: `app/controllers/concerns/authentication_base.rb` (`log_in`,
  `with_actor_session_lock`, `commit_login_session_under_actor_lock`, `commit_login_session!`, and
  receipt creation); `app/models/client_secret_sign_in_receipt.rb`; `rg` results for production
  creation and receipt writer call sites.
- Finding: the only production receipt writer is reached under the Zenith actor lock, then the
  issuance path holds the OP SignInFlow cycle lock. The receipt callback re-locks that OP flow and
  reads the Zenith Client and claimed credential without row locks. The callback and validations do
  not acquire a principal row lock. No reverse edge was found in this direct creation path.
- Limit: this source trace does not prove that external callers never enter with an OP lock already
  held, nor does it exhaust unrelated callbacks.
- Verification: no test or database command was run; this was source inspection only.
