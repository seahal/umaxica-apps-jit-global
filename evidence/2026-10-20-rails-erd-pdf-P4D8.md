# Rails ERD PDF configuration

- Commit: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`.
- The worktree contained extensive pre-existing uncommitted changes, including the addition of
  rails-erd 2.2.0. This change adds `.erdconfig`, ruby-graphviz, and its lockfile entries;
  verification ran with these uncommitted changes present.
- `bundle install` completed successfully.
- Graphviz `dot` is available at `/usr/bin/dot`.
- `bundle exec ruby -rrails_erd -e 'puts RailsERD.options.values_at(:generator, :filetype).inspect'`
  returned `[:graphviz, :pdf]`, confirming the repository configuration is loaded.
- `bundle exec erd` loaded the application and reported 1,014 models, but failed with
  `ActiveSupport::DeprecationException` because the gem calls deprecated
  `ActiveRecord::Base.connection`. The CLI returned exit status zero despite reporting this failure.
  No `erd.pdf` was generated.
- Full application PDF generation remains blocked by that compatibility issue. No application
  deprecation policy was changed. No Minitest or Vitest tests were added for tooling configuration.
