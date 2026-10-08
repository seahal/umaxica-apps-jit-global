# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class DeadIdentifierHistoryVisibilityInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      PUBLIC_BOUNDARY_GLOBS = %w(
        app/controllers/**/*.rb app/serializers/**/*.rb app/presenters/**/*.rb
        app/helpers/**/*.rb app/views/**/* app/notifiers/**/*.rb app/adapters/mcp_*.rb
        config/routes.rb config/routes/**/*.rb
      ).freeze

      %w(Email Telephone).each do |channel|
        test "#{channel} dead history has no ordinary product rendering API or MCP reference" do
          model_names = %w(Client Visitor Operator).map { |realm| "#{realm}#{channel}History" }
          table_names = model_names.map { |name| name.constantize.table_name }
          forbidden_reference = Regexp.union(*model_names, *table_names, "IdentifierHistoryFingerprintVerifier")
          offenders =
            PUBLIC_BOUNDARY_GLOBS.flat_map { |pattern| Rails.root.glob(pattern) }.uniq.filter_map do |path|
              next unless path.file?
              next unless File.read(path).match?(forbidden_reference)

              path.relative_path_from(Rails.root).to_s
            end

          assert_empty offenders,
                       "Dead identifier history belongs to internal lifecycle/legal procedures, not product boundaries"
        end
      end
    end
  end
end
