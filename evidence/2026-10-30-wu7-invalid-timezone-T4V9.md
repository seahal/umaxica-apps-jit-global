# WU-7 timezone screen invalid input

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The existing surface screen test expected an invalid timezone to redirect back to the edit page, while the new com implementation returned an empty 422. The selected cases before the change had 4 runs and 1 failure.
- The com timezone screen now redirects invalid input to its edit page, matching the existing screen behavior. Its integration case verifies that invalid language and timezone inputs create no preference. The related com screen selection passed: 43 runs, 355 assertions, zero failures, errors or skips. RuboCop passed on the changed concern and journey test.
- No localized error message is asserted by the existing redirect test; it checks the redirect and absence of flash. Full-suite comparison was not re-run in this slice.
