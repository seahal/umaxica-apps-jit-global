# WU-A6 ORG Standby Email registration entry

This slice adds a public HTTP check that a Standby session cannot start the Step-Up-protected ORG
Email registration flow.

## Observed result

`BasePasskeyMutationStepUpTest` issued a seeded Standby Operator token and its matching Base ORG
Browser RP credentials, then sent the protected Email registration actions `new`, `create`, `edit`
and `update`. Every response was 403. The Operator's Email row count and Step-Up Ceremony count did
not change, and the token remained in the Standby context.

The focused case passed after the four actions were added: 1 run, 12 assertions, 0 failures, 0
errors, 0 skips. An initial line selection at the preceding test ran the existing APP/ORG Passkey
mutation test instead; that test also passed (1 run, 107 assertions). The Email registration case
was run by its actual line and passed in the final revision.

Scoped `bin/rubocop test/integration/base_passkey_mutation_step_up_test.rb`, Ruby syntax checking,
and `git diff --check` passed. The test code contains no production behavior change.

## Limits and worktree

This is one seeded-session HTTP boundary. It does not establish the real Standby Root issuance
journey, Normal/Standby comparison for every operation, or completion of AC-41. The full suite was
not run in this slice. Verification used the configured local test databases only; no production or
Neon database was accessed.

The work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this
evidence file was added, `git status --short` reported 569 entries. Existing uncommitted work was
present, including changes to the integration test and `four.md`; no commit was created.
