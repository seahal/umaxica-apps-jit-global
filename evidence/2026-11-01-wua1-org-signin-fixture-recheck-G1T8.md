# WU-A1 ORG sign-in fixture recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the
  worktree had 503 modified tracked paths and 238 untracked paths; none were staged.
- Ran
  `PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/unit/security/sign_entry_classification_guard_test.rb test/controllers/auth/org/sign_ins_controller_test.rb`
  after loading `.env.container.devcontainer`. It reported 16 runs, 38 assertions, 0 failures and 9
  errors. All nine errors occurred during ORG fixture insertion: `persona_memberships.enterprise_id`
  referenced a missing Enterprise, before those tests reached their assertions.
- Re-ran the classification guard alone. It passed (7 runs, 38 assertions, 0 failures, 0 errors, 0
  skips).
- Earlier evidence records the six ORG sign-in page tests passing after their admission helper was
  updated (`evidence/2026-10-31-wua1-org-signin-admission-N7C5.md`). This current fixture error
  neither confirms nor contradicts those controller assertions. No application code, schema or
  database rows were changed in this recheck.
- The full suite and the complete WU-A1 runtime matrix were not run.
