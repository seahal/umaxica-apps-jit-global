# WU-7 issuance retention deadline

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- Added a lifecycle read that compares a supplied time with the last issued JWT expiry plus 30 days, and reused that grace-period constant in the existing com save and reset retention calculations. It does not authorize deletion or inspect audit and hold references.
- Before the change, the com model and write-journey tests passed: 59 runs and 337 assertions. After the change, those tests and com Web Push initialization passed: 89 runs and 728 assertions, zero failures, errors or skips. The new model test covers one second before, exactly at and one second after the deadline for both active and retired rows, plus missing time.
- RuboCop passed for the lifecycle concern, write boundary and com model test. Formatting-only fixes were also applied to 20 affected test files using specific RuboCop layout cops. The state diagram and transition inventory were updated.
- The helper is not a purge job. Owner-database clock selection, audit/hold checks, concurrent deletion, batch behavior, final legacy column removal, the full suite and WU-7 completion remain unverified. No migration was run in this slice.
