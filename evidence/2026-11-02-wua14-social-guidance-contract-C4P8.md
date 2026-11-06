# WU-A14 BL-22 verified social-crossing guidance contract

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained 546 changed tracked paths
and 266 untracked paths at the verification snapshot; none were staged. `social_auth.rb` already
contained substantial uncommitted behavior changes from prior work. This slice changed its stale
comment and updated `docs/security/sign-up-sequence.md`; it changed no runtime behavior.

The accepted R-AU-23 behavior is implemented before the uniform social-refusal branch: only a
verified provider callback whose identity conflicts with its APP entry receives fresh-entry
guidance. Other sign-path refusals remain uniform. The comment now describes that exception, and the
current sign-up sequence document records the clean-entry and no-reuse boundary.

Verification:

- `PARALLEL_WORKERS=1 bin/rails test test/integration/social_login_admission_test.rb:821 test/integration/social_login_admission_test.rb:850`:
  2 runs, 30 assertions, 0 failures, 0 errors, 0 skips. This covers an ordinary uniform refusal and
  the verified crossing guidance.
- `bin/rubocop app/controllers/concerns/social_auth.rb`: no offenses.
- `ruby -c app/controllers/concerns/social_auth.rb` and scoped `git diff --check`: passed.
- The full Rails suite was not run.
