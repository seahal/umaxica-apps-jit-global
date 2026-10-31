# Com browser binding schema preparation

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affect the proposed implementation.
- Generated an additive migration for a separate com browser binding table with a unique preference foreign key, required 64-character lowercase hexadecimal digest, and no digest uniqueness constraint. Added the model and preference association. Existing cookie-column data and readers/writers were not changed.
- Ruby syntax checks passed for the migration, new model and model test. `bundle exec rubocop db/com_settings_migrate/20261030164914_create_com_preference_browser_bindings.rb app/models/com_preference_browser_binding.rb app/models/com_preference.rb test/models/com_preference_browser_binding_test.rb` reported no offenses.
- The migration and model tests were not run: Rails test startup automatically applies pending migrations, and two.md reserves database construction for separate approval. The generated structure dump, existing digest migration, storage cutover, rebinding behavior and remaining two.md work are unverified and incomplete.
