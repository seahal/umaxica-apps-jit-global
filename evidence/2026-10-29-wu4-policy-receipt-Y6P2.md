# WU-4 policy and receipt boundaries

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted changes, including corporate model removal and these edits, affected the result.
- Client Chronicle access now permits clients and denies operators and anonymous callers without resolving the removed Visitor class. Step-Up method selection no longer references the deleted visitor actor.
- Processor erasure receipts now reject the retired corporate surface through the existing unsupported-surface error. App receipt processing remains covered.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/client_chronicle_policy_test.rb`: 3 runs, 6 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/services/step_up/available_methods_test.rb`: 14 runs, 26 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/models/processor_erasure_notification_delivery_contract_test.rb`: 17 runs, 63 assertions, no failures, errors or skips.
- No full-suite rerun was performed after these changes. Rails test database preparation was used; no production persistence operation or external write was performed.
