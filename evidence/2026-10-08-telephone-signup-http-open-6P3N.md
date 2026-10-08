# Telephone signup HTTP verification remains open

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes affected these checks.

`bin/rails test test/controllers/auth/app/up/telephones_controller_test.rb
test/controllers/auth/com/up/telephones_controller_test.rb` initially stopped before controller
behavior: 55 runs, zero assertions, 55 errors from missing sign-in state references. Each test
class now constructs its realm's sign-in, signup and signup-cleanup semantic DEFAULTS in setup.

The rerun executed actual behavior: 55 runs, 833 assertions, eight failures, zero errors or skips.
Open failures cover APP resend delivery (three cases), APP exact cooldown boundary, APP/COM
rate-limited creator responses, and APP/COM already-verified resend responses. Regression versus
pre-existing behavioral/test-clock mismatch has not yet been established for these eight cases.
They remain failing acceptance evidence, not ignored or accepted completion.

Focused RuboCop passed for both files (two files, no offenses). No production or external state
was changed. Full proof ownership and final verification remain incomplete.

## Subsequent resolution

The eight failures were resolved without weakening limits or skipping cases. The two controller
files passed 55 runs and 895 assertions (seed 17186). Rate-limited creator outcomes now stop
before delivery and binding; resend cases control the source database clock and anchor cooldown
to `otp_last_sent_at`, including the exact thirty-second boundary.

Telephone preparation now requires a concrete Telephone receiver and a valid Time/TimeWithZone
clock, and assigns the explicit issuance timestamp unconditionally. Its new invalid-input tests
initially produced two failures in seven runs/45 assertions. After the implementation change,
the service plus both HTTP files passed 62 runs/954 assertions (seed 40481), with zero failures,
errors or skips. Focused service/branch-test RuboCop passed. This does not certify removal of
identifier-backed HOTP or complete delivery migration.
