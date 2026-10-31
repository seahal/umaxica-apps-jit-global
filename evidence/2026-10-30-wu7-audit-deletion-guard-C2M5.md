# WU-7 com preference audit deletion guard

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked worktree changes affected the result.
- Changed the com preference Chronicle association from dependent destruction to a deletion restriction. The public model test attempts to destroy a preference with an existing Chronicle entry and verifies both records remain.
- Before the change, the com model and write-journey tests passed: 60 runs, 346 assertions. The first implementation using `restrict_with_error` failed the new test because the Japanese association translation was absent; switching to `restrict_with_exception` removed that dependency. The final run passed: 61 runs, 351 assertions, no failures, errors or skips. RuboCop passed on the model and test before that one-word restriction change.
- This Active Record association guard does not protect direct SQL, `delete_all`, or a cross-database race with a concurrent audit insertion. It does not implement the required purge job, hold checks, or WU-7 completion. No migration or full suite was run.
