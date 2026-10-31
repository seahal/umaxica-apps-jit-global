# Com preference update response binding

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected the checks.
- The shared preference response previously checked the binding only when both the consented flag and a stored digest were present. It now requires a matching digest before returning any category for records carrying a browser binding digest.
- `bin/rails test test/integration/anonymous_com_preference_response_binding_test.rb`: 2 runs, 5 assertions, no failures or errors. A public theme update hides an unbound functional setting, preserves its stored value, and returns it for a matching binding.
- `bin/rails test test/integration/anonymous_com_preference_response_binding_test.rb test/integration/anonymous_com_web_push_api_test.rb`: the earlier combined run passed 6 tests and 30 assertions before the matching-browser test was added. RuboCop on the changed concern and test reported no offenses.
- The independent binding table and full two.md implementation remain incomplete.
