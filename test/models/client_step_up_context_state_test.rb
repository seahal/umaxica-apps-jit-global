# frozen_string_literal: true

require "test_helper"

class ClientStepUpContextStateTest < ActiveSupport::TestCase
  test "the persisted state reference set matches the OP contract" do
    assert_equal [10, 20, 90, 91, 92], ClientStepUpContextState.order(:id).pluck(:id)
  end
end
