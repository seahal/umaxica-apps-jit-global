# WU-A14 APP session-limit route rendering

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had 560 tracked paths with
  uncommitted changes and 280 untracked paths; none were staged. No commit was created.
- Added public route assertions to the APP Visa session-limit journey in
  `test/integration/oidc_rp_browser_flow_test.rb`.
- Ran
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_browser_flow_test.rb:58`:
  1 run, 45 assertions, no failures, errors or skips.
- The request verifies the Inertia component, challenge value, screen labels and non-continuable
  state. Each displayed opaque session reference resolves to exactly one of the actor's current
  sessions, and the displayed set equals that inventory.
- Ruby syntax, scoped RuboCop and `git diff --check` passed. The full file had passed earlier in
  this slice (14 runs, 223 assertions), before these additional page assertions. The full Rails
  suite was not run.
- This closes the route-rendering verification gap reported in
  `evidence/2026-11-02-wua14-session-limit-screen-5K8D.md`; it does not close all WU-A14 candidates.
