# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_statuses
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorTokenStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = OperatorTokenStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, OperatorTokenStatus::ACTIVE
    assert_equal 0, OperatorTokenStatus::NOTHING
    assert_equal 102, OperatorTokenStatus::EXPIRED
    assert_equal 103, OperatorTokenStatus::RESTRICTED
    assert_equal 104, OperatorTokenStatus::REVOKED
  end
end
