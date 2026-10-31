# WU-7 com creation audit rollback

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A public consent write with signing failure previously rolled back the setting row but left a new `ComPreferenceChronicle` record. The write boundary now encloses the setting transaction in a Chronicle transaction, so this pre-commit failure rolls back both. A successful write still records its creation audit.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb`: 81 runs, 789 assertions, 0 failures, 0 errors, 0 skips. RuboCop found no offenses in the boundary and changed test.
- The setting and Chronicle commits are separate. A Chronicle commit failure or process interruption after the setting commit can leave a committed preference without its audit; this check does not establish atomic cross-database commit or recovery. WU-7 remains incomplete. No migration or full suite was run.
