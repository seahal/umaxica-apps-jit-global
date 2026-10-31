# WU-7 com initial preference expiry

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

Before the change, the selected com database-clock issuance and Web Push initialization tests passed: 25 runs, 335 assertions. A newly created com preference previously derived its legacy expiry column from the application clock even though its JWT used the setting database clock. The creation path now passes the integer-second database decision time plus the configured 400-day JWT lifetime to the existing creation writer. App and org callers retain their existing expiry behavior.

After the change, `bin/rails test` on the com Preference write journey, Web Push initialization, and Web Push API integration files passed: 71 runs, 684 assertions, no failures, errors, or skips. The issuance test controls the database decision time and verifies that the new row's legacy expiry equals the signed JWT's `exp`. RuboCop passed for the changed Ruby files.

This does not implement the required issuance snapshot columns or lifecycle redesign. In particular, an existing row's legacy expiry is not extended by subsequent writes, so it can expire before a newly issued JWT. Purge, concurrency and destructive schema changes remain incomplete and require the separate documented approval where applicable.
