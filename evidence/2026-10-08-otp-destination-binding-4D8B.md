# OTP destination binding

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. The worktree contained uncommitted implementation
changes affecting these results. Only local test databases were used.

Six public ceremony regressions reproduced acceptance of a previously issued code after replacing
the normalized destination digest: six runs, six failures, seed 15582. The Email and Telephone keyed
verifiers now bind their respective normalized digest, independently. Their terminal-fact guards
also protect that field. No old-verifier fallback was introduced.

The seven-file ceremony matrix passed 58 runs and 383 assertions, seed 62517, using the ordinary
16-process Rails test execution. The files cover destination replacement, late delivery, deadlines,
lifecycle, terminal facts, ownership and concurrent consumption. Focused RuboCop on the two modified
concerns and destination regression file passed.

These results certify the ceremony primitives, not completion of signup/registration transport
migration. Source-row HOTP callers and broader verification gates remain open.

The destination cases were subsequently extended through the public delivery boundary: delivery
must return false without entering its transport block after destination replacement. This focused
file passed six runs and 24 assertions, seed 49663, without failures, errors or skips.
