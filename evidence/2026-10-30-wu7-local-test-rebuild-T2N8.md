# WU-7 local test database rebuild

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained staged, unstaged, and untracked changes affecting the result.
- The owner stated that no pre-incident backup exists and authorized rebuilding the non-production environment. Under the test database process lock, `RAILS_ENV=test bin/rails db:migrate:reset:com_setting db:migrate:reset:chronicle` completed with exit 0. The configured test connections target `test_com_setting_db` and `test_chronicle_db` on the local `primary` service. Production and Neon were not targeted. This replaced both test databases; the missing original Chronicle row was not recovered.
- A test-environment Rails runner subsequently counted zero com preference parents, browser bindings, web pushes, and com preference chronicles. The post-incident snapshots described in `2026-10-30-wu7-recovery-snapshots-B7M4.md` were not restored.
- With the current test database catalog from `.env.container.devcontainer` exported and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb` passed: 39 runs, 294 assertions, zero failures, errors, or skips.
- This does not establish the remaining WU-7 requirements, a full-suite result, schema-dump parity, or approval for the separately gated section 4.3 destructive migration.
