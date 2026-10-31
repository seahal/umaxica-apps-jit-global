# Com Web Push initialization and binding format

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected these results.
- `bin/rails test test/controllers/concerns/preference_browser_binding_format_test.rb` automatically applied the additive `20261030120000` migration to the existing test com setting database before running. This was an unintended database change; it created two tables and a check constraint, and did not remove existing data. The previously recorded result that the migration had not been applied was accurate at its time but no longer describes the test database.
- `bin/rails test test/models/com_preference_web_push_test.rb test/controllers/concerns/preference_browser_binding_format_test.rb test/integration/anonymous_com_retired_consent_test.rb`: 4 runs, 25 assertions, no failures or errors after fixing strict-loading assumptions in the model test.
- `bin/rails test test/integration/anonymous_com_web_push_initialization_test.rb`: 1 run, 5 assertions, no failures or errors. A Base consent write created one disabled Web Push record and did not put its value in the JWT.
- RuboCop reported no offenses on the changed binding concern and the corresponding tests. The com structure dump was not regenerated; Web Push authorization and independent browser binding storage remain incomplete.
