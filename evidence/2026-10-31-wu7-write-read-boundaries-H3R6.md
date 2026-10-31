# WU-7 local com read and write boundaries

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes in the
worktree affected the result.

`PARALLEL_WORKERS=1 bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb
test/integration/anonymous_com_web_push_initialization_test.rb` passed: 75 runs, 1,195 assertions,
zero failures, errors or skips. The exercised cases include prefetch GET/HEAD with no database
writes, invalid JWT writes creating defaults without mutating the referenced row, reset retirement
and replacement, duplicate cookie rejection, and an issued expiry of 400 days. This result covers
these integration files, not all WU-7 acceptance conditions.

The full-suite baseline comparison and actual collection approval remain unresolved; this record
does not establish WU-7 completion. No production or Neon database was targeted.
