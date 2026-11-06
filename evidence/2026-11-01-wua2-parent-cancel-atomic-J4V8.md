# WU-A2/A3 Parent Cancel Atomicity

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was already dirty with unrelated and in-progress WU changes; those changes were
preserved. No commit was created.

## Changes

- OIDC parent Cancel now stores the cancellation handoff and commits the parent `canceled` state
  while holding the parent row lock. Authentication registration and finalization therefore cannot
  win after Cancel commits.
- Auth App/Org Cancel ends the admitted ceremony and commits its OIDC parent Cancel in one Ticket
  transaction. Same-SID cancellation replay remains supported.
- OIDC-backed Visa session-limit Cancel commits the parent cancellation with the resolution and
  sign-in Flow cancellation before following the Visa cancellation continuation. Local/social
  resolution still returns to the neutral entry.
- Curfew cancellation now uses parent, binding, then ceremony lock order and commits those
  transitions together.
- Updated the Client and Operator OIDC authorization diagrams, transition inventory, and
  public-entrypoint security documentation.

## Verification

- Targeted service/model and cancellation integration command: 33 runs, 417 assertions, 0 failures,
  0 errors, 0 skips.
- After formatting the touched OIDC transaction model test,
  `bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb`: 15 runs, 203
  assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on 11 changed controller/concern/test files: no offenses. The dirty
  `app/services/base_auth_admission_coordinator.rb` was excluded because existing offenses are in
  `create_or_reuse_binding!`; the HEAD version of that file has no offenses.
- `git diff --check`: passed.
- The full suite was not run in this pass. An earlier targeted APP Secret test in the ongoing work
  returned 503 where it expected 303 on two attempts; its cause remains unisolated and it is outside
  these cancellation paths.
- The approved WU-A3 state-shape migrations were not run in this pass. WU-A2/A3 and the overall
  `two.md` implementation remain open.
