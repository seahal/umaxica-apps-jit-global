# WU-7 Warp com read-only cookie notice

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

Warp com now receives a cookie notice with no endpoint and an absolute Base com cookie-settings link. The React notice has no consent buttons and performs no consent fetch or write. A public integration test forwards a valid Base-issued display JWT to Warp and checks dark-theme rendering, no com preference-table queries, no invocation of the private-key lookup, and no preference or binding Set-Cookie. The static call guard does not establish process-level secret isolation or realm-specific keys.

Before the change, the Warp com root/settings tests passed with 13 runs and 65 assertions, and the two React suites passed 36 tests. After the change, the Warp root/settings and com initialization tests passed with 41 runs and 442 assertions; the targeted Warp chrome contract passed with 1 run and 8 assertions. The React suites passed 37 tests. TypeScript build, targeted RuboCop, `oxlint`, and `oxfmt --check` passed.

A broader run of the Warp controller and surface-chrome files reported 17 runs, 127 assertions, no failures and one error in `SurfaceChromePreferenceControlsTest#test_families_with_a_preference_endpoint_hand_each_control_its_same-origin_endpoint`; that name is present in the recorded baseline and the error occurred in its Auth admission setup. No configured browser/DevTools tool was available, so real-browser visual and interaction checks were not performed. Realm-separated keys and the remainder of WU-7 remain incomplete.
