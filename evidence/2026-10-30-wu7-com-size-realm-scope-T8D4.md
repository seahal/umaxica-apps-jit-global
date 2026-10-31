# WU-7 com JWT size scope

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The shared decoder applied the com 3,072-byte limit to legacy app and org tokens even though WU-9 has not replaced those realms. A new codec test generated signed legacy tokens above that limit; they were rejected before the change and decode afterward. The com limit is still applied before parsing on com hosts.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb test/services/preference_token_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`: 77 runs, 548 assertions, 0 failures, 0 errors, 0 skips. The com codec tests include the nearest representable sizes on either side of the limit.
- RuboCop found no offenses in the changed codec and test. This does not implement the later app/org WU-9 size contract, realm-specific keys or complete WU-7. No migration or full suite was run.
