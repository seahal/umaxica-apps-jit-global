# WU-A6 ORG credential-removal transaction fixture boundary

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 556 staged, unstaged or
  untracked status entries when recorded; no commit was created. This test file was modified in that
  worktree.
- The ORG credential-removal integration uses a writer that requires an independent OP commit. Its
  transactional fixture previously caused the writer to reject its caller-owned transaction,
  producing 503 responses where the assertions expected the operation result. The APP counterpart
  already uses nontransactional tests with exact cleanup.
- Converted the ORG integration test to nontransactional execution, declared only its required
  reference fixtures, tracked the exact operators created by each test, and explicitly removed their
  dependent OP, Zenith and Base authority graph rows during teardown.
- One initial run reached teardown but a test-created Base Bureau ownership row blocked deleting its
  operator. The exact generated test actor and its dependent test graph were identified and removed
  from the local test database; teardown was extended to remove that graph in dependency order. No
  schema, migration, development, production or Neon data changed.

## Verification

- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer RAILS_ENV=test bin/rails test test/integration/sign/org/credential_removal_constraints_test.rb`
  — two consecutive completed runs, each 5 runs, 20 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/integration/sign/org/credential_removal_constraints_test.rb` — 1 file
  inspected, no offenses.
- `ruby -c test/integration/sign/org/credential_removal_constraints_test.rb` — Syntax OK.
- `git diff --check -- test/integration/sign/org/credential_removal_constraints_test.rb` — passed.

This resolves the ORG test's independent-commit fixture mismatch only. WU-A6 AC-41 still lacks the
full operation-by-operation Normal and Standby session matrix, and reviewed Standby Root issuance
shape remains pending.
