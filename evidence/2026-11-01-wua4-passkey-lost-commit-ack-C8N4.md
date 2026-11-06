# WU-A4 XDB-02 Passkey rename lost commit acknowledgement

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was already extensively dirty and had no staged changes. The test and documentation
updates in this record are uncommitted.

Added an APP/ORG operation test that commits the Zenith Passkey description and audit, disconnects
the connection before acknowledging the commit, and injects
`ActiveRecord::ConnectionNotEstablished`. Both surfaces return
`IdentityPasskeyNameCommitter::DependencyFailure`; fresh reads observe the new description, one
audit row, and consumed Step-Up proof.

Verification:

- Before the test change,
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/operations/identity_passkey_name_committer_test.rb`:
  13 runs, 92 assertions, 0 failures, 0 errors, 0 skips.
- With the new case, the same operation file: 14 runs, 100 assertions, 0 failures, 0 errors, 0
  skips. This run preceded a formatting-only RuboCop correction.
- After that correction, the focused case at line 270: 1 run, 8 assertions, 0 failures, 0 errors, 0
  skips.
- `bundle exec rubocop test/operations/identity_passkey_name_committer_test.rb`: clean after the
  correction.
- `ruby -c test/operations/identity_passkey_name_committer_test.rb`: syntax OK.
- `git diff --check -- test/operations/identity_passkey_name_committer_test.rb`: clean.

The full suite was not run. This verifies the lost-ack outcome for the two tested operation paths;
it does not close the wider XDB-02 failure-window or HTTP delivery audit.
