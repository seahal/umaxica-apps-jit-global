# Signup phase proof fixtures

Commit: `6405c465c82dd45625d294ad8f8c2fe7827a4390`; uncommitted worktree changes affect results.

The twelve APP signup phase-regression tests now use original local admission, public Base
confirmation and actual encrypted notifier code bound to typed ceremony generation. No Source HOTP
reconstruction or new helper is used. Existing fixed refusals, absorbing halt/completion, stale-tab
isolation, audit disclosure restrictions and unusable-binding sentinels remain asserted. The
original Email controller consumption case now asserts its named verified signup status and erased
ceremony verifier instead of reading obsolete Source HOTP. An old response-body debug print was
removed to prevent unintended disclosure.

The first phase run produced one expiry-fixture error (12 tests/174 assertions, seed 48239): a
historical Ruby clock preceding the real database clock made issuance correctly refuse the flow.
Issuance now uses the real database clock, and the pending test flow has a shorter one-minute
deadline within its original admission, never an extended authority. The next expiry-boundary run
exposed Rails travel_to microsecond truncation (13 tests/188 assertions, seed 38866). Installed
Rails time_helpers.rb confirms with_usec defaults false; explicit with_usec:true preserves the
PostgreSQL deadline when probing its exact boundary.

The final normal command selecting the whole phase file and the existing OTP-consumption case passed
13 tests/195 assertions, no failures/errors/skips, seed 9975. Rails used its normal 16-process
configuration because the controller file's unfiltered size crosses the threshold; only thirteen
selected tests actually ran. Whole-suite verification remains incomplete. Scoped RuboCop passed both
affected files, and git diff --check passed.
