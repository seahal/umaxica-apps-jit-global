# Telephone fixed-deadline resend

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. The worktree contains uncommitted changes.

The four migrated registration operation files first ran 214 tests, 2,614 assertions, no failures,
34 errors and no skips (seed 44680). All errors referenced the missing independent Telephone
resend issuer. The new three-realm ceremony reissue file separately reproduced the missing
primitive: 12 tests, 15 assertions, nine failures, three errors, no skips (seed 34503).

After implementing the independent Telephone primitive and resend issuer, the primitive plus
resend selection passed 86 tests and 1,219 assertions (seed 10418). The primitive plus the four
registration operation files passed 226 tests and 3,183 assertions (seed 49156), without failures,
errors or skips. Commands used normal `bin/rails test` without additional environment settings.

The checks cover generation replacement, stale transport rejection, fixed parent/OTP deadlines,
terminal refusal, original ownership/browser/Root/candidate, failure budgets and Source-write
rollback. The maximum UUID fixture is opaque generation data, not a HOTP arithmetic boundary.

After a behavior-preserving local-variable extraction to satisfy complexity limits, scoped
RuboCop passed for the Telephone concern, resend issuer and primitive test. The post-refactor
primitive/resend selection passed 86 tests and 1,219 assertions (seed 30676), without failures,
errors or skips. Full Rails, full lint and final architecture/security gates have not run.
Direct-SQL terminal-proof protection and Source legacy proof retirement remain incomplete.
