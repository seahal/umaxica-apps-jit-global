# WU-7 issuance values

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- Section 3.4 names `PreferenceDisplayValue` and `PreferenceWriteResult`; neither file existed before this slice. The com issuance boundary now builds a validated immutable display snapshot, signs that snapshot, constructs its language and experience values from it, and carries the signed result to post-commit cookie emission. This replaces the previous mutable issuance hash.
- Before the change, the selected issuance and signing-failure cases passed: 13 runs, 141 assertions. After the change, the display value, JWT shape, issuance guard, com write, initialization, consent and Web Push files passed: 124 runs, 1,622 assertions, zero failures, errors or skips. RuboCop corrected formatting on the two new files after the run.
- This does not establish the remaining shared write-entry signature, all transaction failure cases, or full-suite success. No migration was performed.
