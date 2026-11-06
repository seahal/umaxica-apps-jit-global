# WU-A6 ORG Standby other-session revocation

This slice checks the Step-Up-protected ORG operation that revokes all other Operator sessions.

## Observed result

`BasePasskeyMutationStepUpTest` issued a seeded Standby Operator token and matching Base ORG Browser
RP credentials, then sent `DELETE` to the other-sessions endpoint. The endpoint returned 403. The
other Operator token remained usable, the request token remained in the Standby context, and the
count of Step-Up Ceremonies for the actor did not change.

The focused case passed: 1 run, 8 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop for
`test/integration/base_passkey_mutation_step_up_test.rb`, Ruby syntax checking, and
`git diff --check` passed.

## Limits and worktree

This is a seeded-session HTTP boundary. It does not establish real Standby Root issuance or close
the complete AC-41 operation matrix. The full suite was not run in this slice. Verification used the
configured local test databases only; no production or Neon database was accessed.

The work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this
evidence file was added, `git status --short` reported 570 entries. Existing uncommitted work was
present, including changes to the integration test and `four.md`; no commit was created.
