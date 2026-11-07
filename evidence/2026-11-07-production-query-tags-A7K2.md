# Production query tags configuration

- HEAD: `271673747d6c940325b3287ab7c1045f5a7549ef`.
- The worktree contains unrelated uncommitted changes. This change adds only query tag enablement in `config/environments/production.rb` and this evidence record; dependency inspection uses the existing worktree lockfile.
- `bundle exec ruby -e 'require "active_record"; puts "Active Record: #{ActiveRecord::VERSION::STRING}"; begin; ActiveRecord::Base.warn_on_records_fetched_greater_than = 1000; rescue NoMethodError => error; puts "Unsupported setting: #{error.class}: #{error.name}"; end'` reported Active Record `8.2.0.alpha` and `NoMethodError` for `warn_on_records_fetched_greater_than=`. That unsupported setting was not added.
- Installed Rails source in `active_record/query_logs.rb` documents query tags as SQL comments; this setting does not configure a 100 ms slow-query threshold.
- `ruby -c config/environments/production.rb`: `Syntax OK`.
- `bin/rubocop config/environments/production.rb`: one file inspected, no offenses.
- Production boot and database logging behavior were not exercised. No Minitest or Vitest configuration tests were added.
