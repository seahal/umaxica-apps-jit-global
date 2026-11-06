# WU-9 Base Preference projection database-failure check

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already had 551 changed or
  untracked paths before this evidence was added; this check ran against that uncommitted state. No
  commit was created.
- The existing `test/integration/preference_read_symmetry_test.rb` passed before this addition: 5
  runs, 50 assertions, 0 failures, 0 errors, 0 skips.
- Added an HTTP GET case that injects `ActiveRecord::ConnectionNotEstablished` from the APP consent
  receipt reader while a valid anonymous Preference JWT and matching browser binding are present.
  The request rendered successfully and retained the JWT theme (`dr`), while consent remained false
  and Web Push remained disabled. The initial assertion used the long snapshot value `dark`; that
  assertion failed because the Actor contract normalizes it to `dr`. After correcting the expected
  representation, the file passed: 6 runs, 56 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop and `git diff --check` passed for the changed integration test. Test commands
  sourced `.env.container.devcontainer` and used `PARALLEL_WORKERS=1`.
- No application code, schema, migration, production/Neon database, or full-suite run was changed or
  exercised in this slice. This verifies the receipt-read failure response for APP Base HTML; it
  does not test independent outages of every reader in all realms. The WU-9 closing AC matrix and
  reserved full-suite baseline comparison remain open.
