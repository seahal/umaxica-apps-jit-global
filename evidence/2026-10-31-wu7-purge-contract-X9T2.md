# WU-7 local preference collection contract

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes in the
worktree affected the result.

`PARALLEL_WORKERS=1 bin/rails test test/jobs/preference_lifecycle_job_test.rb
test/concurrency/com_preference_write_purge_test.rb
test/concurrency/com_preference_purge_rollback_test.rb
test/concurrency/com_preference_audit_purge_test.rb` passed: 19 runs, 106 assertions, no failures,
errors or skips. These tests cover the public job, retention boundary, audit references, concurrent
writes and a child deletion rollback in the local test environment.

Automatic collection is not scheduled; the separately approved actual purge described in
`two.md` section 4.9 has not been executed. This result does not establish WU-7 completion.
