# WU-3 surface and realm verification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained extensive uncommitted WU-3 changes from multiple contributors, realm-boundary changes, and the tests described below.
- `bin/rails test`: 17,534 runs, 143,671 assertions, 139 failures, 224 errors, 0 skips. Compared by test name against the baseline `b6e7871073bdc43a55fc5f05e8476de8ee71252f` inventory, no failing identifiers were new. The smaller run count includes removed tests and HEAD differences; this does not itself prove that removed cases were appropriately replaced.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb test/controllers/base/com/roots_controller_test.rb`: 41 runs, 749 assertions, no failures or errors.
- SQL notifications during the public anonymous Base com root, preference index and theme screen confirmed that no queried connection was outside corporate settings or Chronicle. Before the change the root queried `com_zenith` through `CurrentBannerQuery`; the two anonymous Base page owners now intentionally omit that banner.
- This is not full WU-3 acceptance: com authority-stop participant handling and related legacy references remain, and the full suite still contains baseline failures. Test database preparation and parallel worker databases were used.
