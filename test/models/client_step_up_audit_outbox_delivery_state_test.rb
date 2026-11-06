# frozen_string_literal: true

require "test_helper"

class ClientStepUpAuditOutboxDeliveryStateTest < ActiveSupport::TestCase
  test "the reference rows contain exactly pending and delivered" do
    assert_equal [10, 20], ClientStepUpAuditOutboxDeliveryState.order(:id).pluck(:id)
  end
end
