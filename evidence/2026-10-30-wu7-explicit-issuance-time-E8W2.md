# WU-7 explicit com JWT issuance time

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained staged, unstaged and untracked changes.
- The com issuance boundary now requires an explicit time and the com codec refuses absent or invalid times instead of substituting the application clock. The normal writer passes its `database_now` decision time. App/org legacy encoding retains its existing contract.
- Before the change, the com token-shape and write-journey tests passed: 59 runs, 493 assertions. After the change, seven com token, request and reader test files passed: 120 runs, 1,104 assertions, zero failures, errors or skips. After test-call formatting, the shape and journey files passed again: 60 runs, 496 assertions. Added coverage checks absent and invalid issuance time and a supplied epoch time.
- RuboCop passed for the two application files and seven changed test files; `git diff --check` passed on those files. This does not establish database snapshot persistence, independent realm signing keys, other WU-7 requirements or the full suite. No migration was run.
