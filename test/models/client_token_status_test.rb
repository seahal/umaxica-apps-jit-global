# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_statuses
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientTokenStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, ClientTokenStatus::ACTIVE
    assert_equal 0, ClientTokenStatus::NOTHING
    assert_equal 102, ClientTokenStatus::EXPIRED
    assert_equal 103, ClientTokenStatus::RESTRICTED
    assert_equal 104, ClientTokenStatus::REVOKED
  end
end
