# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # The ten-Passkey limit is a model count check that PasskeyRegistrationOperation serializes
    # under the owner lock; the database does not enforce it. A Passkey created any other way can
    # exceed the limit, so application code must not create Passkey rows directly
    # (plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md).
    class PasskeyRegistrationWriterInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      DIRECT_WRITE =
        /\b(?:ClientPasskey|VisitorPasskey|OperatorPasskey|(?:client|visitor|staff|operator)_passkeys)
          \.(?:create!?|create_with|find_or_create_by!?|create_or_find_by!?|insert_all!?|insert!?|upsert_all|upsert)\b/x

      test "application code creates Passkeys only through PasskeyRegistrationOperation" do
        offenders =
          Rails.root.glob("{app,lib}/**/*.rb").flat_map do |path|
            path.each_line.with_index(1).filter_map do |line, number|
              "#{path.relative_path_from(Rails.root)}:#{number}" if line.match?(DIRECT_WRITE)
            end
          end

        assert_empty offenders, "create Passkeys through PasskeyRegistrationOperation instead"
      end
    end
  end
end
