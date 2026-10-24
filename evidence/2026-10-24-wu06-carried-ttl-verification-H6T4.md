# WU-06 carried-value verification

Date: 2026-10-24
Revision tested: `58c52567e2066cce2bc882335c375713f8eedb41`

The worktree contained unrelated staged-free changes from other implementation work. The checks
below were run against that dirty worktree; the targeted files were isolated in the staged diff.

## Passing checks

- Targeted admission, result, Visa exit, social, Discovery and revocation coverage:
  `99 runs, 1,121 assertions, 0 failures, 0 errors, 0 skips`.
- Full OIDC token exchange service coverage:
  `101 runs, 471 assertions, 0 failures, 0 errors, 0 skips`.
- Base admission coordinator coverage including carried transport/result lifetime tests:
  `22 runs, 149 assertions, 0 failures, 0 errors, 0 skips`.
- `bin/rubocop` on the 15 changed implementation and test files: no offenses.
- `bin/rails zeitwerk:check`: all eager-loaded application code passed.
- `git diff --cached --check`: passed.

The carried-value tests assert that admission transport, result delivery and authorization-code
expiry do not exceed the redeemed authentication Binding's curfew. The exact-curfew value object
test also asserts that 30:00 is outside the window.

## Checks not used as release evidence

Broader legacy controller groups still contain failures caused by unrelated in-progress Visa
redirect changes in the dirty worktree (old tests expect direct Auth 2xx responses while the
current path redirects through Visa ceremony binding confirmation). Those failures were not
included in the targeted pass count above.
