# WU-7 write failure on generation collision

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A public theme save was tested with the generation source returning a generation already assigned to another row. The actual model uniqueness validation rejected the rotation. Before the change the endpoint returned 422; it now reports a 503 persistence failure, rolls back the theme and original generation, and does not emit a replacement preference JWT.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_web_push_initialization_test.rb`: 80 runs, 782 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop found no offenses in the write boundary and changed journey test. This does not prove database commit-failure behavior, realm-specific keys, or WU-7 completion. No migration or full suite was run.
