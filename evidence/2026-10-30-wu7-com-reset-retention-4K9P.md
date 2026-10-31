# WU-7 com reset retention

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

Before the change, the com Preference journey and Web Push initialization tests passed: 62 runs, 613 assertions. On reset, the legacy writer previously replaced the old row's purge deadline without considering a later existing deadline. Under the existing parent-row lock, com reset now retains the later of that deadline and the presented current JWT expiry plus 30 days. The retirement and replacement remain in the same setting transaction. The app/org reset callers retain their prior behavior.

After the change, `bin/rails test` on the com Preference journey, Web Push initialization and Web Push API files passed: 74 runs, 716 assertions, no failures, errors, or skips. The reset test checks the existing deadline one second below, at, and one second above the JWT grace deadline. Existing tests check retirement, replacement, stale JWTs and signing rollback. RuboCop passed for the four changed Ruby files.

This preserves an existing infinite legacy deadline rather than shortening it, so it is not evidence that expired rows are eventually purged. The explicit lifecycle, last-issued snapshot, hold-aware purge and separate-connection races remain incomplete. No destructive migration or production data operation was performed.
