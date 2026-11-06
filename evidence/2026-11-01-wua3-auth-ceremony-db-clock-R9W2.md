# WU-A3 Auth Ceremony transition clock ownership

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The pre-existing worktree was retained. During the
checks it had 512 tracked changed paths and 242 untracked paths; no staged changes were present. No
commit or migration was made in this slice.

Auth Ceremony transition writers no longer accept a caller-supplied `now:` for admission,
authentication evidence, revocation, completion, cancellation, SID rotation, or replacement
admission. Each writer reads `database_now` after acquiring its row/transaction lock. App call sites
now invoke those writers without forwarding another database's timestamp. Query predicates still
accept an observation time. Tests that need historical lifecycle facts set expiration data or stub
the model's public database clock.

Verification:

- The focused Auth Ceremony session, replacement concurrency, revocation concurrency, and Admission
  Binding retention command passed: 47 runs, 459 assertions, 0 failures, 0 errors, 0 skips.
- The operation-level follow-up covered token status management, Step-Up cancellation/finalization,
  Step-Up retention, TOTP finalization, and credential security transitions: 88 runs, 227
  assertions, 0 failures, 59 errors, 0 skips. Inspected errors stopped during fixture setup with
  cross-database foreign-key violations involving missing Client rows; those cases did not reach
  their operation assertions.
- Ruby syntax checks and `git diff --check` passed.
- Targeted RuboCop inspected 15 files and reported 6 offenses in
  `test/models/auth_ceremony_revocation_concurrency_test.rb`; the other 14 inspected files had no
  reported offenses. The offenses were not changed in this slice.
- A source search found no App call to the Auth Ceremony state-transition writers that supplies
  `now:`.

The local App/Org development and test state-shape migrations were already recorded as `up` after
the owner's approval in `evidence/2026-11-01-wua3-migration-status-refresh-F4T2.md`; they were not
reapplied. The full suite and WU-A3's complete AC matrix were not run. The ORG Switch contract
discrepancy and fixture-blocked operation checks remain open; this evidence does not close WU-A3 or
the broader `two.md` implementation.
