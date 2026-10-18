# Ceremony terminal database protection

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree contains uncommitted changes.

The user explicitly approved limited SQL functions and UPDATE triggers for the six APP/COM/ORG
Email/Telephone ceremonies. Three generated forward migrations now protect consumed or cancelled
OTP facts and original binding. They grant no roles, change no existing records, and preserve
ordinary parent completion. Each local test Ticket database migration was applied, rolled back
and reapplied successfully using its exact new version. No production operation was performed.

The original twelve SQL-erasure regressions were RED (12 failures, seed 20744; evidence 7C2D).
The expanded terminal test plus finite-deadline, ORM terminal, primitive, receipt and Telephone
reissue tests passed 46 tests and 863 assertions, zero failures/errors/skips, seed 56425.
Six old receipt tests attempted timestamp replacement after consumption; they now require SQL
rejection, unchanged proof and refusal at the original deadline. Scoped RuboCop passed all three
migrations and the terminal database test. A preceding command could not load a nonexistent
test filename; it ran no tests and is not recorded as successful verification.

Identifier HOTP columns and old serialized Source proof still await coherent retirement.
Whole-suite and final harness verification are incomplete; this is not overall completion.
