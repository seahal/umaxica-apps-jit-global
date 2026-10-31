# WU-7 setting commit failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- Before adding the test, the existing same-JWT save/reset and reset rollback selection passed: 3 runs, 36 assertions.
- Added nontransactional request tests that create synthetic preferences through the public API, then inject `ActiveRecord::StatementInvalid` at the setting adapter's commit call. For an existing consent update, the parent, cookie choices, receipt and binding stayed unchanged. For reset, the old parent stayed active, no replacement or reset audit remained. Both returned 503 and emitted no shared preference or binding cookie. Test cleanup removed only the synthetic records and their audits.
- The two commit-failure cases and existing concurrency file passed: 4 runs, 68 assertions, zero failures, errors or skips. RuboCop corrected formatting afterward. The injection occurs before the adapter sends COMMIT; it does not simulate a lost connection with an unknown commit outcome or a Chronicle commit failure after a successful setting commit. Full-suite comparison remains outstanding.
