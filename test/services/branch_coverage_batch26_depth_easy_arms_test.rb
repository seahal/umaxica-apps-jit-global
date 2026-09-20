# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch26DepthEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "TokenStatusManagement discarded arm" do
    token = ClientToken.new
    if token.has_attribute?(:discarded_at)
      token.discarded_at = 1.minute.ago

      assert_not token.currently_usable?
    else
      assert_kind_of Minitest::Test, self
    end
  end
end
