# Warp COM settings preference reader

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting this check.
- Added a Warp COM settings HTTP case with a signed COM Preference JWT. The rendered HTML uses the signed language and theme, and the response does not issue a replacement Preference JWT.
- The SQL notification listener saw neither `com_preference` SQL nor SQL attributed to the `com_setting` or `com_setting_replica` Active Record configurations during this request. The focused case passed (1 run, 11 assertions); before the final connection-name assertions were added, the combined root/settings files passed (17 runs, 150 assertions). RuboCop and scoped `git diff --check` passed.
- SQL notifications do not prove that no connection was ever checked out or opened without a query. This does not establish every preference or cookie boundary, a real browser, or production key distribution. The last full-suite run predates this test.
