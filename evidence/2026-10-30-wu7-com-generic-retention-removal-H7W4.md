# WU-7 com preference generic retention removal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- Removed `ComPreference` and `ComPreferenceChronicle` from the generic retention job. The generic job deletes by retention time without the required com audit and hold checks. The public job test sets both test records past their legacy deadlines, runs the job and verifies both still exist. The general Retainable registry test now recognizes these two specialized exclusions.
- Before the change, the retention job and com model tests passed: 46 runs, 171 assertions. The first post-change run errored because the new test selected retention times before fixture creation; after correcting its setup, the same files passed: 47 runs, 175 assertions, zero failures, errors or skips. RuboCop passed for the job and test.
- No lifecycle-specific purge job has been implemented; these records are not purged by this generic job. Hold-aware deletion, concurrency, the old retention-column removal, full-suite comparison and WU-7 completion remain outstanding. No migration was run.
