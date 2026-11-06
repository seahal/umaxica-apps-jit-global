# WU-A6 Base-root Step-Up boundary recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the shared
worktree had 562 modified tracked paths and 287 untracked paths; none were staged. Existing changes
were preserved and no commit was created.

The owner selected an Authority-only Base confirmation that requires a Base root token. The existing
`BaseCeremonyBindingConfirmation` implementation enforces this: a Step-Up binding must match
`current_session_token`, and the no-token branch refuses `step_up_handoff`. No application
controller or schema code changed in this slice.

`OrgRootLoginEstablishmentTest` now asserts that the Visa/RP-only journey cannot confirm a
Base-authority Step-Up binding: the confirmation returns 400, the binding remains attached,
`base_confirmed_at` remains unset, and the Root token's Step-Up timestamp remains unset. Its
targeted run passed: 1 run, 65 assertions, 0 failures, 0 errors, 0 skips.

The ORG administrative Step-Up integration test supplies a Base root token and covers the positive
path. Its browser requests now include document-navigation metadata; its idempotent completion retry
uses the rotated RP cookies returned by the first response. The full file passed: 10 runs, 102
assertions, 0 failures, 0 errors, 0 skips. The focused positive case passed: 1 run, 33 assertions, 0
failures, 0 errors, 0 skips.

Scoped RuboCop inspected both edited integration files with no offenses. Ruby syntax checks and
scoped `git diff --check` passed. The full Rails suite was not run. The direct RP-to-Auth-to-RP
Step-Up flow remains outside the Authority-only confirmation contract and is not established by
these tests.
