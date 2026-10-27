# Mapped acceptance cases: run and status

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle changes.
- Selection: `three.md` rows still "Not run" whose `seven.md` stage 2 row is "Mapped" — 41 cases; 28
  of them name test files (29 files), 13 name only evidence or prose and were left as they are.
- `PARALLEL_WORKERS=1 bin/rails test` on the 29 files: 346 runs, 4,939 assertions, 0 failures,
  5 errors — all 5 in `test/controllers/auth/app/social/ceremony_entry_test.rb` (pre-Design-D entry,
  full-suite triage group A).
- Set to Passed (every mapped file green; the case-to-test mapping is the one recorded in `seven.md`,
  not re-read here): A02-1 A02-2 A02-5 A02-6 A02-9 A02-12 A05-4 A06-2 A06-6b A07-0 A07-1c A07-1e A07-2 A07-3 A08-1 A10-1 A10-5 A12-1 A13-2 A25-3 A27-2 A29-1 A29-3 A29-5 A29-6 A29-7 A34-5
- Left Not run: A05-3 (its mapped file errors) and the 13 Mapped rows without a test file.
