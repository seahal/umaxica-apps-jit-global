# frozen_string_literal: true

require "test_helper"

class RpBaseOrgStepUpStateStatusTest < ActiveSupport::TestCase
  test "the persisted status reference set matches the RP contract" do
    assert_equal [10, 15, 20, 90, 91, 92, 93], RpBaseOrgStepUpStateStatus.order(:id).pluck(:id)
  end
end
