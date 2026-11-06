# frozen_string_literal: true

require "test_helper"

class RpStepUpAuditOutboxDeliveryStateTest < ActiveSupport::TestCase
  test "the reference rows contain exactly pending and delivered" do
    assert_equal [10, 20], RpStepUpAuditOutboxDeliveryState.order(:id).pluck(:id)
  end
end
