# WU-7 preference CSRF test ordering

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- In the full suite the cross-site preference test observed 200 on auth/app instead of 403; running it alone passed. Running the CSRF notification test followed by the preference test with seed 2 reproduced the failure: 2 runs, 44 assertions, 1 failure. The notification test assigns the auth/app controller's class-level forgery setting, which can persist independently of the base controller setting.
- The preference test's existing protection setup now explicitly enables and restores the auth/app controller setting as well. The same ordered pair passed: 2 runs, 99 assertions, zero failures, errors or skips. This is a test isolation change; no production CSRF enforcement was changed.
- The full suite has not been re-run after this change. The reconstruction failures and other baseline-external candidates from `2026-10-30-wu7-full-suite-recheck-W8C4.md` remain unresolved or unclassified.
