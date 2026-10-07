# Shared verification budget Contact integration

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`; inherited and current uncommitted changes affect all results.

CommonOtp consumers now explicitly supply surface/purpose/channel, and the authoritative destination
digest is read from the reloaded Contact under its lock. The external budget executes before OTP
consumption. Actual wrong comparisons still increment candidate limits; an otherwise correct code
denied by the shared budget does not invent a candidate failure. Existing recovery/reentry consumers
use distinct purpose scopes as a required interface dependency, not an unbudgeted fallback.

- The new app sign-in HTTP regression first exposed an old admission setup (400 before OTP), then
  a candidate missing its effective binding. After arranging those public prerequisites, it was red:
  a correct OTP passed an exhausted budget and redirected (1 run, 4 assertions, 1 failure; seed 2294).
  After integration it passed (1 run, 7 assertions; seed 57323). The equivalent com HTTP case passed
  (1 run, 7 assertions; seed 33423). The existing candidate five-failure case, with an effective
  binding arranged, and the new app case passed together (2 runs, 14 assertions; seed 39873).
- The new com settings HTTP refusal passed: 1 run, 6 assertions (seed 23140). It retains the OTP and
  leaves finalization/release absent, with no invented candidate lock or failure.
- After the locked-digest correction, `bin/rails test test/controllers/auth/app/in/emails_controller_test.rb
  test/controllers/auth/com/in/emails_controller_test.rb -i '/shared_authentication_budget|locks_after_five/'`
  passed: 3 runs, 21 assertions, no failures/errors/skips (seed 42).
- Six app/com/org email/telephone registration files initially passed (89 runs, 399 assertions;
  seed 58854). Re-running after the locked-digest correction at seed 48957 exposed a setup collision:
  a second-browser allocation exceeded COM's unchanged two-session limit. It reproduced in the
  matrix but not alone (single case 1 run, 14 assertions passed). A public setup assertion showed
  roots 1228 and 1817 where only the setup root was expected. A read-only probe confirmed root 1228
  was created at `2026-10-07 00:57:15 UTC`, referenced visitor 859741814, and that owner was absent
  outside the case. Fresh random test identity IDs avoid this inherited disposable-fleet orphan;
  no root was deleted and no production cap was weakened. The same seed then passed all six files:
  89 runs, 400 assertions, no failures/errors/skips.
- Signup/budget verification after adding four-realm/channel dependency-failure preservation checks
  passed: 27 runs, 241 assertions, no failures/errors/skips (seed 53623). Concurrent budget requests
  use twelve independent real Valkey connections. Correct and wrong OTPs both refuse dependency
  outage without changing Ticket or Contact facts.
- Recovery/reentry direct consumers initially failed (16 runs, 78 assertions, 5 failures, 5 errors;
  seed 44553): old fixtures had only verified status and no effective binding, and two recovery
  status actions called an absent root cookie helper after Base RP reparenting. Fixture prerequisites
  and the production cookie dependency were repaired. The same three files passed afterward:
  16 runs, 110 assertions, no failures/errors/skips (seed 21929). Cookie construction/deletion uses
  existing CoreCookieOptions with the prior host-only Strict/HttpOnly/secure protection; root
  authentication is not reintroduced.

These are targeted incremental results, not Final Verification. Dummy/timing parity, dispatch limits,
historical recognition, clean fleet construction and the complete plan fault matrix remain open.
No Task checkbox, COM distribution contract, ten-credential count or provider GET callback was changed.
