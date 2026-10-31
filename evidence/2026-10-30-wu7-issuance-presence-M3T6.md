# WU-7 issuance timestamp presence

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged and untracked changes affected the result.
- The completed full suite exposed `NotNullColumnNilValidationContractTest#test_ComPreference_NOT_NULL_columns_reject_nil_before_SQL`: `last_issued_at` was not rejected by model validation. Added presence validation for both issuance timestamps and a model test covering missing and populated timestamps. The database NOT NULL constraints remain in place.
- Before the fix the targeted invariant failed. The invariant and focused model case then passed: 2 runs, 10 assertions. The com write journey and consent receipt integration selection passed after the change: 55 runs, 808 assertions, zero failures, errors or skips. RuboCop passed on the changed model and test.
- The full suite was run before this change and is not a full-suite verification of it. Other baseline-external failures, reset audit, OpenAPI, the JWT type discrepancy and WU-7 completion remain unresolved. No migration was run.
