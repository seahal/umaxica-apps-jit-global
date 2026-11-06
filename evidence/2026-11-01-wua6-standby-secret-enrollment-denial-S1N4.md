# WU-A6 ORG Standby Secret enrollment refusal

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty (573 staged, unstaged, or
  untracked status entries at verification); no commit was created.
- The integration test seeds an ORG Standby Browser RP session and sends `new` and `create` requests
  to Secret enrollment. Both return 403. The Operator has no new Secret credential, Secret
  enrollment transaction or Step-Up ceremony; the token remains Standby.
- The focused case passed: 1 run, 12 assertions, 0 failures, 0 errors, 0 skips. The full affected
  integration file passed: 4 runs, 139 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop inspected the integration and Avatar controller test files with no offenses. Ruby
  syntax checks returned `Syntax OK` for both files. `git diff --check` passed for the touched test,
  documentation and evidence files.
- The test setup is inline and creates two active Passkeys so the request reaches the
  Standby-specific boundary. No application behavior, migration, or production/Neon data was
  changed.
- This is partial AC-41 evidence. It does not establish real Standby Root issuance, the full
  policy-derived Normal/Standby operation matrix, or the remaining Avatar accept/cancel boundaries.
  The full suite was not run.
