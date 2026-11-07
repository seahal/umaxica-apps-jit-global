# Explicit strict loading on application model bases

- HEAD: `271673747d6c940325b3287ab7c1045f5a7549ef`.
- Verification used the uncommitted worktree, including unrelated pre-existing changes. This change adds `self.strict_loading_by_default = true` to all 28 application-owned abstract bases under `app/models/` and documents the setting in the model database inventory.
- The existing application-wide strict loading default was already true. Database connections, framework-owned models, strict loading modes, and association-specific overrides were not edited.
- `RAILS_ENV=test bin/rails runner` with an explicit array of all 28 abstract bases and `bases.all?(&:strict_loading_by_default)` succeeded: `Strict loading enabled on 28 abstract bases`.
- `bin/rubocop $(rg -l 'self.strict_loading_by_default = true' app/models)`: 28 files inspected, no offenses.
- `bin/rails test test/models/application_record_test.rb`: 11 runs, 19 assertions, no failures, errors, or skips.
- `git diff --check -- 'app/models/*record.rb' docs/architecture/model-database-inventory.md`: passed.
- Production boot and full test suite were not run.
