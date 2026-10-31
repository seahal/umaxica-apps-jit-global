# Sign-up current scope documentation check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including changes affecting the checked code and documentation.
- Compared the sign-up sequence's admission, Flow expiry, report scope and birthdate descriptions with the current implementation and eligibility policy. Updated the current summary and explicitly marked the remaining COM route and lifecycle material as historical pending reconciliation.
- With `PARALLEL_WORKERS=1`, ran `bin/rails test test/models/client_sign_up_flow_test.rb:52 test/controllers/auth/app/up/emails_controller_test.rb:1736`: 2 runs, 23 assertions, no failures or errors.
- `git diff --check -- docs/security/sign-up-sequence.md` passed. The remaining historical sections and all end-to-end ceremony deadlines were not verified by this check.
