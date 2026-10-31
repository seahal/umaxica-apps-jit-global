# WU-7 post-rebuild codec checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained staged, unstaged, and untracked changes.
- After the owner authorized rebuilding non-production databases, removed the temporary fixture preflight introduced in `2026-10-30-wu7-fixture-preflight-P6K2.md`. That guard was intended to protect test data from fixture replacement and would otherwise block subsequent runs when test rows exist. The earlier record describes the guard as it existed at that time.
- With the current test database catalog exported and `PARALLEL_WORKERS=1`, `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/values/security_jwt_preference_token_codec_claims_test.rb` passed: 24 runs, 229 assertions, zero failures, errors, or skips.
- The codec still uses the shared `preference` signing namespace for com; section 12.7 requires independent realm namespaces. These checks do not establish realm-key separation or WU-7 completion. No section 4.3 destructive migration or full suite was run.
