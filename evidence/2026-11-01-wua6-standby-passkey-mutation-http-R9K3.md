# WU-A6 ORG Standby Passkey mutation refusal

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty (563 staged, unstaged, or
  untracked status entries at verification); no commit was created.
- `test/integration/base_passkey_mutation_step_up_test.rb` extends the existing ORG
  credential-removal scenario with a seeded Standby operator token, matching Passkey Step-Up
  freshness, and a signed ORG access token. The Base Passkey rename (`PATCH`) and removal (`DELETE`)
  endpoints both refuse with HTTP 403. The test verifies that the Passkey description and active
  status, token freshness, and Standby context remain unchanged, and that neither request creates a
  Step-Up transaction.
- These are two operation boundaries with seeded session state. They do not establish the Standby
  Root login/binding journey or the complete AC-41 Normal/Standby operation matrix.

## Verification

- Before adding the DELETE assertion, the rename-only test passed three consecutive runs (1 run, 102
  assertions each).
- After adding DELETE refusal and unchanged-state assertions, the final version passed two
  consecutive runs (1 run, 107 assertions each), with 0 failures, 0 errors, and 0 skips.
- `bundle exec rubocop test/integration/base_passkey_mutation_step_up_test.rb` — 1 file inspected,
  no offenses.
- `ruby -c test/integration/base_passkey_mutation_step_up_test.rb` — Syntax OK.
- `git diff --check -- test/integration/base_passkey_mutation_step_up_test.rb four.md` — passed.

No schema, migration, development database, production, or Neon data was changed for this check.

## Follow-up: details page

The same public Standby-session test now also requests the Passkey details `GET` while matching
fresh Step-Up evidence is present. The details page, rename and removal each return HTTP 403 and
preserve Passkey description/status, token context/freshness and ceremony count. The focused APP/ORG
scenario passed (1 run, 113 assertions, 0 failures, 0 errors, 0 skips); scoped RuboCop, Ruby syntax
and `git diff --check` passed. This remains seeded-session evidence, not the real Standby Root
issuance journey or the complete AC-41 matrix.

Follow-up verification used HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree remained
dirty with 587 staged, unstaged, or untracked paths. No commit was created.
