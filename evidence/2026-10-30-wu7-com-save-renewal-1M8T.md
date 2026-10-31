# WU-7 com save renewal with legacy retention

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

Before this change, the com initialization and preference write-journey tests passed: 60 runs, 593 assertions. The existing legacy preference expiry was not extended when a new JWT was issued for an existing row. The com write transaction now sets the row expiry to the new signed JWT expiry after signing and retains the later of the existing purge deadline and that expiry plus 30 days. The normal named retention writer performs the update before the setting transaction commits; a failed signature does not reach it.

After the change, `bin/rails test` on the com Web Push initialization, preference write-journey and Web Push API integration files passed: 73 runs, 704 assertions, no failures, errors, or skips. Tests cover a subsequent save, consent read after the original JWT expiry, infinite existing retention, and a finite existing purge deadline one second below, at, and one second above the new grace deadline. RuboCop passed on the changed Ruby files.

This uses existing legacy retention columns until the required schema redesign. It does not establish the final last-issued snapshot, expiry-driven purge job, holds or concurrent saves. The separate reset writer still computes its own legacy purge deadline and requires lifecycle review. No destructive migration or production data operation was performed.
