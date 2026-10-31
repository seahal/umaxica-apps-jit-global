# WU-7 com identity constraints

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The focused com identifier tests initially produced 8 errors because their setup created a com preference without the now-required issuance timestamps and generation. The tests now construct valid com preferences, use the current issuance transition for a mutable-field check, and use the current retirement transition for the retired-row identity check. The SQL identity constraint assertions remain in place.
- The com selection passed: 8 runs, 33 assertions. Both complete identifier test files then passed: 59 runs, 205 assertions, zero failures, errors or skips. RuboCop corrected formatting afterward; the suite was not re-run after formatting.
- Full-suite comparison remains outstanding. No migration was executed in this slice.
