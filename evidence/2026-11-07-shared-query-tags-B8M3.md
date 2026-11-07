# Shared query tag configuration

- HEAD: `271673747d6c940325b3287ab7c1045f5a7549ef`.
- Uncommitted changes are present, including unrelated work. This follow-up moves the previously added query tag enablement from `config/environments/production.rb` to `config/application.rb` for all environments. Existing development and test settings already use the same value.
- `ruby -c config/application.rb` and `ruby -c config/environments/production.rb`: both reported `Syntax OK`.
- `bin/rubocop config/application.rb config/environments/production.rb`: two files inspected, no offenses.
- `git diff --check -- config/application.rb config/environments/production.rb`: passed.
- Application boot and SQL execution were not verified; no environment-construction tests were added.
- The unsupported record-fetch warning setting remains absent. See `2026-11-07-production-query-tags-A7K2.md` for the dependency check.
