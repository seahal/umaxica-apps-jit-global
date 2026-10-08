# COM email authentication proof fixtures

Commit: `6405c465c82dd45625d294ad8f8c2fe7827a4390`. The worktree contained uncommitted
implementation, migration, schema and test changes.

The nineteen existing COM Email sign-in cases retain their assertions. Correct/wrong-code fixtures
now decrypt the actual queued delivery payload and validate its generation and Contact binding
against the admitted Auth ceremony. They no longer overwrite identifier HOTP material. Turnstile
refusal preserves the entire ceremony proof and candidate failure count. Successful verification
asserts the ceremony's verified result and result deadline instead of identifier expiry. Unused
identifier secret/counter fixture attributes were removed. No production behavior changed.

- `bin/rails test test/controllers/auth/com/in/emails_controller_test.rb`: 19 runs, 179 assertions,
  zero failures/errors/skips; seed `31644`, 6.568477 seconds.
- Initial updated fixtures: 19/150, two failures, seed `36887`; the Mailer path deliberately has no
  delivery `public_id`, so assertions were corrected to the actual ceremony `contact_ref` and
  generation. No fallback was introduced.
- `bundle exec rubocop test/controllers/auth/com/in/emails_controller_test.rb`: one file, no
  offenses.
- `git diff --check`: passed.

An independent terminal's full run finished before this focused run. Its existing log reports 14,841
runs, 114,904 assertions, 859 failures, 466 errors and one skip. That run was not launched by this
agent and overlapped uncommitted work; failure attribution and final full verification remain
outstanding. It is not a passing final gate.

The next attempted focused MFA run was interrupted before executing tests because an independent
terminal started another full suite (PID `2869729`). This agent interrupted only its own PID
`2879840`, which was waiting in `ParallelTestDatabaseCloner.acquire_test_process_lock!`. No other
terminal's process was stopped, and no MFA result or passing gate is claimed.
