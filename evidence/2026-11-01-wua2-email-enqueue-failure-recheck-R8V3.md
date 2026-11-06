# APP sign-up email enqueue failure recheck

Date: 2026-11-01 HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8` Worktree: contained many existing
uncommitted changes; none were reverted and no commit was created.

With `.env.container.devcontainer` loaded, ran:

```sh
PARALLEL_WORKERS=1 bundle exec bin/rails test test/controllers/auth/app/up/emails_controller_test.rb:649
```

The selected test
`test_create_beside_a_non-finalized_verified_signup_candidate_owns_independent_evidence` failed: it
expected 1 enqueued job and observed 0 (1 run, 2 assertions, 1 failure, 0 errors, 0 skips). The same
test had failed in the earlier run recorded in
`evidence/2026-11-01-wua2-a3-cancel-secret-recheck-H7P2.md`. The cause remains unisolated after
these two reproductions; no further investigation was performed in this slice. This is an unresolved
WU-A2 candidate, not classified as a baseline failure or attributed to a specific change. The full
suite was not run.
