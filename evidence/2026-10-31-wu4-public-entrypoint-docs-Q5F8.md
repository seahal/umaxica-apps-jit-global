# Public authentication entrypoint documentation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting the check.
- Compared `docs/security/public-entrypoints.md` with the current Auth APP/ORG route scopes and cancellation/Switch controllers. Updated the prose to remove retired COM Auth Step-Up/setup and Email OTP references, distinguish APP-only Switch from APP/ORG Cancel, and describe the current Visa GET continuation. The separately recorded WU-9 requirement to move the Visa commit to a POST remains unresolved; this documentation describes current code, not completion of that change.
- `PARALLEL_WORKERS=1 bin/rails test test/unit/security/public_entrypoint_inventory_test.rb` passed: 6 runs, 71 assertions, no failures, errors or skips. Scoped `git diff --check` passed. This verifies the named inventory test, not every public authentication journey.
