# Jump return path boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected these checks.
- Return URL parsing refuses paths beginning with `//`, which would become protocol-relative when the verified path is used as the redirect target. Root and ordinary absolute paths remain accepted. The signed-token verifier and durable Jump checklist cover this boundary.
- `bin/rails test test/values/jump_rt_return_url_value_test.rb test/services/jump_rt/return_verifier_test.rb test/services/jump_rt/return_policy_test.rb`: 147 runs, 723 assertions, no failures or errors.
- `bundle exec rubocop app/values/jump_rt_return_url_value.rb test/values/jump_rt_return_url_value_test.rb test/services/jump_rt/return_verifier_test.rb`: no offenses.
- This does not establish full WU-A11 or two.md completion.
