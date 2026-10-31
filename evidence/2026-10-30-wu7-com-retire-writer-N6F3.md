# WU-7 com retirement writer

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- Added `PreferenceLifecycle#retire!`, which locks the row and accepts only the statically declared active status before writing the retired status. The com reset boundary uses this writer within its existing transaction; legacy retention and token fields are still updated in that transaction. App/org retain their existing reset writer. A repeated retirement raises and leaves the row retired.
- Before the change, the com write-journey and model tests passed: 59 runs, 342 assertions. After the change, those tests and the com Web Push initialization tests passed: 89 runs, 727 assertions, zero failures, errors or skips. The model test exercises a first and repeated retirement; the existing request tests exercise reset and signing rollback.
- RuboCop passed for the four changed application Ruby files, and `git diff --check` passed for the tracked files checked. The com status diagram and transition inventory were updated.
- This does not enforce every possible direct status update or establish the final issuance snapshot, new retention schema, concurrency acceptance, purge, key separation, full-suite result or WU-7 completion. No migration was executed in this slice.
