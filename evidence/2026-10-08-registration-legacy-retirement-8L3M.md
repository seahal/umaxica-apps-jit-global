# Registration legacy retirement checkpoints

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted worktree changes affected these results. Only local test resources were used, without extra environment variables or production operations.

The unused cross-realm `SignSettingsEmailRegistration` concern, its no-op issuance calls and its remaining obsolete reset-hook calls were removed. Concrete channel/realm finalizers already own current registration. `SignEmailRegistrable` no longer exposes dead Source HOTP issuance/verification, pending-owner creation or legacy delivery methods. Its guest signup caller explicitly owns independent issuance and delivery; authenticated callers own their initiation.

The first five-file HTTP/regression run after removing the concern found seven COM reset-hook errors (100 tests, 925 assertions, seed 36004). Removing the obsolete reset dependency fixed these regressions; current host-local candidate and original-child references are still cleared explicitly.

`bin/rails test test/controllers/base/app/identity/emails/registrations_controller_test.rb test/controllers/base/com/identity/emails/registrations_controller_test.rb test/controllers/auth/app/up/emails_controller_test.rb test/controllers/concerns/sign/email_registrable_included_do_test.rb test/operations/sign_up_otp_delivery_issuer_test.rb`: 100 tests, 973 assertions, zero failures/errors/skips, seed 20836. Scoped RuboCop on these tests and six affected production boundaries: seven files, no offenses.

Independent implementation-worker checkpoints:

- Registration delivery-lock and transport-binding migrations: 42 tests, 762 assertions, zero failures/errors/skips, seed 50508. Existing scenarios remain on independent Email/Telephone APIs rather than shared Source proof.
- ORG Telephone registration: initial migration RED 20 tests/79 assertions, ten errors, seed 26182; after implementation GREEN 20 tests/149 assertions, no failures/errors/skips, seed 20073. Eleven production and three controller-test files were reported lint clean.
- Separate APP/COM Telephone management-create paths remain reachable: their subsequent 59-test batch reproduced two missing-session-ID errors (373 assertions, seed 43959). Fixes are under verification; this evidence does not claim those paths passed.

ORG Telephone uses its numeric identifier ID explicitly, not an invented public-ID accessor; its own named model transition and existing passkey-only/current-Root policy remain distinct from APP/COM binding/audit state. Source commits before Ticket receipt. No new ORG audit outbox was invented.

Six ceremony terminal-proof SQL protection regressions, Source-column retirement and full Rails/lint/harness/inventory/architecture gates remain unfinished. Goal completion is not claimed.
