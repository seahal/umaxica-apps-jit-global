# Typed delivery contract retirement

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree has uncommitted changes.

The two old shared counter-binding Value definitions had no remaining Ruby callers after the
signup delayed-transport fixture migration and independent channel Value test migration. Both
Git-tracked files were removed and remain recoverable from Git. Their 14 existing test scenarios
now exercise typed Email/Telephone transaction/generation bindings, including boundaries, malformed
inputs, purpose mismatch and immutability. The two-file selection passed 14 tests and 532 assertions,
no failures/errors/skips (seed 52463). Scoped lint and diff checks passed.

Telephone adapter's arbitrary keyword sink silently ignored foreign transport metadata. Its test
first reproduced the problem: four tests, seven assertions, one failure, no errors/skips (seed 5263).
Removing the sink makes unknown keywords raise before transport; explicit current bindings are
unchanged. The adapter/factory/delayed-signup/Telephone-delivery/HTTP/registration-delivery selection
passed 125 tests and 1,372 assertions (seed 28141), without failures, errors or skips. Three scoped
Ruby files passed RuboCop.

Old identifier proof columns, remaining shared operations and terminal SQL protection have not been
retired. Full Rails, full lint, security harnesses and final architecture gates remain unverified.
