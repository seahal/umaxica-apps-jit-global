# ORG Passkey registration commit-boundary failures

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had extensive uncommitted
  changes; it contained 494 `git status --short` entries immediately before this evidence file was
  added. The APP commit-order test also contained prior uncommitted work.
- Added nontransactional ORG XDB-01 tests using a verified registration candidate and scoped Step-Up
  evidence. An injected OP commit failure leaves the ticket verified, Step-Up unspent, candidate
  unconsumed, ceremony incomplete, and no new Passkey or audit. An injected ORG Zenith commit
  failure leaves OP consumption and Step-Up spending committed, while the Passkey and audit remain
  absent; retry refuses without creating a credential.
- With explicit local `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com`,
  `PREFERENCE_COM_JWT_AUDIENCE=com`, and empty `PREFERENCE_COM_JWT_REVOKED_KIDS`,
  `PARALLEL_WORKERS=1 bin/rails test test/operations/org_passkey_registration_commit_order_test.rb`
  passed: 2 runs, 19 assertions, 0 failures, 0 errors, 0 skips. The two selected cases separately
  passed with 9 and 10 assertions.
- Added lost-acknowledgement cases that execute the real commit, disconnect the connection, then
  raise. OP acknowledgement loss leaves consumption durable without an ORG credential (1 run / 8
  assertions); Zenith acknowledgement loss leaves its credential and audit durable and retry returns
  the same credential (1 / 6).
- The expanded APP and ORG commit-order files passed together: 11 runs, 79 assertions, 0 failures, 0
  errors, 0 skips. `ruby -c`, scoped `git diff --check`, and RuboCop on the new ORG test file
  passed. No application code, schema, migration, or database data was changed in this slice.
- The ORG XDB-01 pre-commit failures and lost-acknowledgement windows are covered.
  Independent-connection outage behavior and the remaining WU-A4 commit-boundary matrix are not
  established.
