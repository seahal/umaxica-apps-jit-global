# Brakeman signup principal ownership lookup

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`, with uncommitted changes present. This fix
changes only the principal lookup in `ClientSecretPasskeyReservationIssuer.complete_sign_up!`;
other in-progress authentication-cycle changes were preserved.

The locked, reloaded Flow now resolves its declared `principal` association through its scoped
relation rather than calling `Client.find` directly. The existing writer role, actor lock,
completed-registration checks and issuance ownership checks are preserved. Missing ownership
continues to fail explicitly. No Brakeman suppression or configuration change was added.

Executed `bin/brakeman -A`: exit 0, **0 scan errors, 0 security warnings**. The scan used the
repository's unchanged configuration, including optional checks and Weak-confidence warnings.
Single-file RuboCop and scoped `git diff --check` passed.

The first focused Rails test attempt was refused before any test ran because another live Rails
test process held the shared test-database lock. That process was not interrupted or bypassed.
After its process exited and the lock was verified free, ran
`bin/rails test test/operations/client_secret_passkey_reservation_issuer_test.rb` successfully:
**4 runs, 244 assertions, 0 failures, 0 errors, 0 skips**. This includes refusing activation before
source registration, subsequent successful activation and replay without duplicate audit records.
