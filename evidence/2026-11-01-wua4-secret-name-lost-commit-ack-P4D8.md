# WU-A4 XDB-05 Secret rename lost Zenith commit acknowledgement

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The shared worktree had extensive pre-existing uncommitted changes, including the XDB-05 operation
  test and implementation. No commit was made; unrelated changes were preserved.
- Added a nontransactional failure-window test that executes the real Zenith `COMMIT`, disconnects
  that adapter, then raises a connection error to model loss of the commit acknowledgement.
- `ClientSecretNameCommitter` returned `DependencyFailure`; a fresh read found the new Secret name
  and exactly one `secret.renamed` event, while the OP Step-Up remained consumed. This does not
  claim that a caller can distinguish committed from uncommitted when the acknowledgment is lost.
- The isolated case passed (1 run, 4 assertions). The full
  `test/operations/client_secret_name_committer_test.rb` file then passed (18 runs, 175 assertions,
  0 failures, 0 errors, 0 skips), including the concurrent same-proof case.
- Scoped RuboCop, Ruby syntax and `git diff --check` passed for the changed operation test. No
  Production or Neon database was accessed; no full suite was run.
