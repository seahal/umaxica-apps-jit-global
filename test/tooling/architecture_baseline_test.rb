# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require_relative "../../lib/architecture_baseline"

# Ratchet for the Umaxica architecture cops.
#
# `.rubocop_todo.yml` keeps `bin/rubocop` green by excluding files that are already in debt, which
# alone would let a new violation slip into one of those files unnoticed. This test measures the
# repository with the excludes ignored and compares against the recorded per-file counts, so a debt
# file may only improve. Regenerate both artifacts with `bin/rails architecture:baseline`.
class ArchitectureBaselineTest < ActiveSupport::TestCase
  def test_no_file_exceeds_its_recorded_architecture_debt
    measured = ArchitectureBaseline.measure
    recorded = ArchitectureBaseline.recorded

    ArchitectureBaseline::COPS.each do |cop|
      recorded_files = recorded.fetch(cop)

      measured.fetch(cop).each do |path, count|
        allowed = recorded_files.fetch(path, 0)

        assert_operator count, :<=, allowed,
                        "#{path} has #{count} #{cop} offenses but the baseline allows #{allowed}. " \
                        "Fix the new violation; do not regenerate the baseline to hide it."
      end
    end
  end

  def test_baseline_and_rubocop_todo_describe_the_same_files
    recorded = ArchitectureBaseline.recorded
    todo = YAML.load_file(ArchitectureBaseline::TODO_PATH, aliases: false)

    ArchitectureBaseline::COPS.each do |cop|
      assert_equal recorded.fetch(cop).keys.sort, todo.fetch(cop).fetch("Exclude").sort, cop
    end
  end

  def test_baseline_does_not_list_resolved_files
    measured = ArchitectureBaseline.measure

    ArchitectureBaseline::COPS.each do |cop|
      stale = ArchitectureBaseline.recorded.fetch(cop).keys - measured.fetch(cop).keys

      assert_empty stale,
                   "#{cop} baseline lists files with no remaining offenses. " \
                   "Run bin/rails architecture:baseline to drop them."
    end
  end
end
