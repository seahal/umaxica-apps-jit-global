# Historical A05-5 existing social identity sign-in

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/social_auth_app_flow_contract_test.rb -n '/(Google|Apple)_sign_in_reuses_existing_social_identity/'`: 2 runs, 24 assertions, 0 failures, 0 errors.
- The cases assert no new Client or social identity, preserve the existing identity's owner, record authentication and redirect to the Base dashboard. Provider and protocol network transport are replaced at test boundaries.
- These assertions do not directly count signup Flows, cover every refusal, or prove deployed provider behavior. The archived mapping's old signup-entry fallthrough expectation differs from `two.md` §10.7, which requires a verified L2 refusal rather than automatic switching; the old case is not counted as a current pass.

## Signup Flow follow-up

- The same two request cases now record the signup Flow count before the sign-in entry and assert that it remains unchanged after the callback and handoff. The focused command passed again: 2 runs, 26 assertions, 0 failures, 0 errors.
- This supersedes the preceding signup Flow limitation. Provider transport is still stubbed, and deployed behavior and other refusal cases were not verified.
- Scoped `git diff --check` passed. RuboCop reported 16 offenses elsewhere in the existing large integration file; none were in the two modified sign-in cases.
