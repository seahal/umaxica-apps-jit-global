# WU-7 com retired transport cookie cleanup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A successful com preference write now expires presented host-only legacy refresh and DBSC cookies after the write boundary returns. The existing app/org refresh behavior is unchanged. GET continues to ignore the retired credentials without issuing deletions, and a signing failure does not queue their deletion.
- The new deletion assertion failed before the change. `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/preference_refresh_replay_test.rb`: 70 runs, 687 assertions, 0 failures, 0 errors, 0 skips. RuboCop found no offenses in the two changed files.
- This does not establish all historical cookie scopes or complete WU-7. Realm-specific keys, lifecycle/schema changes and full-suite verification remain incomplete. No migration was run.
