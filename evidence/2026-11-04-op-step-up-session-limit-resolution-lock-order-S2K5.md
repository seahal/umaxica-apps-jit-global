# Session-limit resolution caller lock-order trace

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; inspected files were in the current worktree.
- Scope: trace APP/ORG session-limit resolution writers and direct controller callers for O-10
  reverse locking.
- Evidence inspected: `app/models/concerns/session_limit_resolution_transactionable.rb`,
  `app/controllers/concerns/base_sign_in_limitations.rb`,
  `app/controllers/visa/app/sign/in/limitations_controller.rb`,
  `app/operations/session_limit_oidc_cancellation_committer.rb`, and
  `app/controllers/concerns/authentication_base.rb` issuance call sites.
- Finding: issue and session-finalization paths take or already hold the actor before OP
  flow/resolution locks. Selection, resolution, cancellation, and expiry use the actor-first
  transition lock; OIDC cancellation uses the actor-first committer. The direct local-cancel branch
  is selected only when there is no OIDC authorization parent. Both Visa authorization-resume
  controllers lock the actor before `finalize_base!` locks the OIDC parent.
- Limit: unrelated callbacks and every exceptional database failure path were not exhausted.
- Verification: source inspection only; no tests or database operations were run in this
  continuation. Existing APP/ORG independent-connection cancellation results remain those recorded
  in `zero.md`; they were not rerun here.
