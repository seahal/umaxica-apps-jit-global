# WU-A1 Sign Entry Sentry focused matrix recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the
  worktree had 504 modified tracked paths and 241 untracked paths; none were staged.
- The final selected Sentry matrix passed: 53 runs / 536 assertions across the classification guard,
  APP/ORG Sentry pages, verified/unavailable parent handling, blocked admission preservation,
  availability toggles, blocked Root boundary, curfew boundaries, and ORG Sign In page controller.
  Additional focused checks passed for admitted APP OTP resend before/after disabling Sign In (1 run
  / 12 assertions), ORG Emergency with normal Sign In blocked (1 / 10), and APP/ORG
  invitation-parent ordering/refusal (3 / 42). All results had 0 failures, errors or skips.
- Fixture loading initially failed on an unrelated missing Enterprise reference from global
  `fixtures :all`. The ORG Sign In test now uses only its `operators` and `operator_statuses`
  fixtures; the resolver test is fixture-free; ORG Emergency uses only its declared eight fixture
  tables. After these test-only changes, the relevant files passed. `ruby -c` passed for the four
  edited test files; RuboCop inspected four files with no offenses; `git diff --check` passed.
- No application behavior code, schema or database rows changed in this slice. The A1 Standby
  exception was verified through Auth-side Standby evidence, not through Visa Root issuance; that
  continuation remains part of the open WU-A6 boundary. The full Rails suite was not run.
