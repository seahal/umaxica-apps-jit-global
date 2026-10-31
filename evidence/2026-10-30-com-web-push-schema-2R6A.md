# Com Web Push storage preparation

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affect the proposed implementation.
- Added a migration for com Web Push option and per-preference tables, model associations, and disabled initialization on new anonymous com preferences. The option table is limited to disabled and enabled. This does not implement delivery or subscriptions.
- Ruby syntax checks passed for the migration, new models, and model test. `bundle exec rubocop db/com_settings_migrate/20261030120000_create_com_preference_web_pushes.rb app/models/com_preference_web_push.rb app/models/com_preference_web_push_option.rb app/models/com_preference.rb app/controllers/concerns/preference_base.rb test/models/com_preference_web_push_test.rb` reported no offenses.
- The migration was not applied and the model tests were not run: `two.md` section 3.4 reserves database construction for separate approval. The generated com structure and runtime behavior remain unverified. Existing browser binding storage and Web Push read/write authorization remain incomplete.
