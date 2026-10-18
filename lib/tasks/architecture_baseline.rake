# typed: false
# frozen_string_literal: true

require_relative "../architecture_baseline"

namespace :architecture do
  desc "Regenerate the Umaxica architecture cop baseline (.rubocop_todo.yml and .rubocop/architecture_baseline.yml)"
  # No :environment dependency: the baseline is measured by a RuboCop subprocess, and requiring a
  # booted application (and therefore a reachable database) would make the task fail for reasons
  # unrelated to static analysis.
  task :baseline do # rubocop:disable Rails/RakeEnvironment
    counts = ArchitectureBaseline.measure
    ArchitectureBaseline.write(counts)

    counts.each do |cop, files|
      puts("#{cop}: #{files.values.sum} offenses in #{files.size} files")
    end
  end
end
