# WU-7 com preference status values

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked work affected the result.
- The com parent previously validated that `status_id` was an integer but did not validate membership in the two defined reference IDs. The new model test initially failed. The model now accepts only `ComPreferenceStatus::RETIRED` and `ACTIVE`; the test checks nil, the neighboring integers 0 and 3, and both allowed values. The local test database at inspection contained reference IDs 1 and 2 and two parents in status 2.
- The com model, lifecycle job, write journey and concurrent consent/reset files passed: 85 runs, 901 assertions, zero failures, errors or skips. RuboCop passed on the model and test. The com state diagram and transition inventory describe the model validation and its direct-SQL limitation.
- This model validation does not enforce the closed status set against direct SQL, validation-skipping writes or changes to the reference table. No migration or non-test purge was performed. Full-suite comparison remains outstanding.
