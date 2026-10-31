# Sign-up eligibility surface validation

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected these checks.
- Unsupported missing, empty and non-string surface inputs now return false from the surface predicate and produce the existing explicit `ArgumentError` at the eligibility boundary. App and org remain supported.
- `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; require "./test/services/sign_up_eligibility_policy_test"'`: 6 runs, 26 assertions, no failures or errors. This fixture-independent test was run with automatic schema maintenance disabled because the new com binding migration is pending.
- `bundle exec rubocop app/policies/sign_up_eligibility_policy.rb test/services/sign_up_eligibility_policy_test.rb`: no offenses.
- A read-only test-environment query found two com preference cookie rows, zero with a binding digest, and zero duplicate digests. This does not measure production data or establish migration approval or recovery.
