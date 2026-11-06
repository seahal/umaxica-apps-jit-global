# WU-A3 Switch binding lifecycle public recheck

- The APP Switch integration cases now assert that each replaced binding reaches `switched` and its
  replacement reaches `redeemed`, for both Sign In → Sign Up and Sign Up → Sign In.
- `RAILS_ENV=test bin/rails test test/integration/sign_entry_exit_flow_test.rb:177`: 1 run, 26
  assertions, 0 failures, 0 errors, 0 skips.
- `RAILS_ENV=test bin/rails test test/integration/sign_entry_exit_flow_test.rb:231`: 1 run, 28
  assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop for `test/integration/sign_entry_exit_flow_test.rb` and
  `test/integration/oidc_initiated_sign_in_completion_test.rb` passed with no offenses;
  `git diff --check` passed.
- Current APP code calls the explicit binding `switch!` transition while creating the replacement
  admission. This corrects the older `four.md` finding that the switched transition was missing. ORG
  remains a separate scope discrepancy: `two.md` names an ORG Switch controller, while the accepted
  sign-up ADR and current ORG tests say there is no public ORG Sign Up or Switch. No ORG route was
  added pending owner direction.
- No full suite was run. These checks do not close all of WU-A3 or `two.md`.
- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had uncommitted changes, including
  the tests recorded here.
