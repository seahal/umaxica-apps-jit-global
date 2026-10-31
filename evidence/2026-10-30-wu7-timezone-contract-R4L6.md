# WU-7 timezone display contract test

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The com case expected the retired individual timezone cookie and failed with a nil value. It now verifies both saved timezone values in the verified com preference JWT; app and org still verify their individual cookies.
- The three surface cases passed: 3 runs, 18 assertions, zero failures, errors or skips. This check confirms the emitted preference value, not the transient `Time.zone` inside the request.
- Full-suite comparison was not re-run in this slice.
