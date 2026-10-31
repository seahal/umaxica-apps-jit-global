# WU-7 com generic preference screen dispatch

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting this result.

Before this change, the com Web Push initialization and API tests passed: 30 runs, 360 assertions. The generic screen controller still used the shared dynamic dispatch and could reach legacy preference writers. The com screen writers are now shared with the dedicated controllers, and the generic controller selects the allowed edit and update operations explicitly. Unknown screens are refused before a write.

After the change, `bin/rails test test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_write_journey_test.rb` passed: 70 runs, 660 assertions, no failures, errors, or skips. Public requests cover the eleven supported screen updates, rejection of an unknown screen, CSRF refusal, and rollback without preference cookies on signing failure. RuboCop passed for the changed controllers and concern; the integration test's call formatting was corrected after the test run.

This does not establish the complete WU-7 lifecycle, realm-key separation, independent-connection races, or destructive schema migration. The full suite was not rerun for this slice.
