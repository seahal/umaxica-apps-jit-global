# OIDC realm normalization after COM retirement

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting this result.
- Ran `PARALLEL_WORKERS=1 bin/rails test test/values/oidc_subject_test.rb test/values/oidc_client_registry_test.rb`: 11 runs, 118 assertions, no failures, errors or skips.
- The current implementation and tests accept client, operator and staff alias and reject missing, empty, unknown and visitor values. `two.md` describes visitor acceptance for WU-1 before WU-3, and explicitly requires visitor rejection once COM registration is removed (dependency 1→3). The current post-removal behavior is consistent with that staged requirement. This run does not independently verify every WU-3 route and participant removal.
