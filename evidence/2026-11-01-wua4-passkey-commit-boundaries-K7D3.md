# Passkey registration commit-boundary failures

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had extensive uncommitted
  changes; it contained 492 `git status --short` entries immediately before this evidence file was
  added. The test file also contained prior uncommitted work.
- Added two cases to `test/operations/identity_passkey_registration_commit_order_test.rb` for the
  XDB-01 first-commit and second-commit failure windows. An injected OP commit failure leaves the
  verified candidate and ticket unconsumed, the ceremony incomplete, and no credential or audit. An
  injected Zenith commit failure leaves OP consumption committed, with no credential or audit; retry
  refuses and creates no credential.
- The first test invocation stopped during Rails initialization because required local
  `PREFERENCE_COM_JWT_*` settings were absent; no test ran. With the explicit local issuer,
  audience, and empty revoked-kid setting used by existing repository evidence, the selected cases
  passed (1 run / 7 assertions and 1 run / 9 assertions). The complete file passed: 5 runs, 33
  assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c` and scoped `git diff --check` passed. RuboCop reported 7 autocorrectable offenses on
  pre-existing lines outside these additions; the added cases introduced no remaining offense.
- Later added lost-acknowledgement cases that execute the real commit, disconnect the connection,
  then raise. APP OP commit acknowledgement loss leaves ticket consumption durable and Zenith
  unchanged (1 run / 7 assertions); APP Zenith acknowledgement loss leaves the credential and audit
  durable and retry returns the same credential (1 / 6). Both ORG equivalents passed in the new ORG
  test file (1 / 8 and 1 / 6).
- The expanded APP and ORG commit-order files passed together: 11 runs, 79 assertions, 0 failures, 0
  errors, 0 skips. After the final formatting-only edit, syntax and scoped whitespace checks passed.
  RuboCop still reported only the 7 existing APP-file offenses; the ORG file had no offenses.
- No application code, schema, migration, or database data changed in this slice. This does not
  establish independent-connection outage behavior or close the broader WU-A4 acceptance.
