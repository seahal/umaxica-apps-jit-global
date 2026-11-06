# WU-A3 cancellation entry navigation metadata

## Change

The APP and ORG cancellation controller tests now send `Sec-Fetch-Mode: navigate` and
`Sec-Fetch-Dest: document` when entering the admitted verification page. The admission endpoint
requires document-navigation metadata for GET requests carrying an entry reference; the prior test
requests omitted both headers and were refused before cancellation behavior ran.

## Verification

- Before the test correction, the focused cancellation/continuation/initial-attach selection had 3
  failures at the initial verification GET (400 instead of 303). The failing controller test IDs are
  recorded in `plans/2026-10-28-baseline-failing-tests.md`.
- After the correction, the same three-file selection passed: 16 runs, 402 assertions, 0 failures, 0
  errors, 0 skips.
- The cancellation controller test file alone passed: 5 runs, 107 assertions, 0 failures, 0 errors,
  0 skips.
- The APP/ORG old-tab refusal after cancel-and-start replacement passed: 2 runs, 30 assertions, 0
  failures, 0 errors, 0 skips (`ceremony_admission_boundary_test.rb`, filtered to that case).
- Targeted RuboCop for the cancellation test file and `git diff --check` passed.
- Tests ran with the required public host and preference JWT environment values explicitly set and
  `PARALLEL_WORKERS=1`.

## Limits and repository state

This confirms the focused public cancellation and WU-A3 initial-attach cases only. It does not close
WU-A3 or the broader `two.md` acceptance. No application code, schema, migration, or database data
was changed in this slice. HEAD was `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already
contained uncommitted changes (495 status entries before this evidence file was added); they were
preserved.
