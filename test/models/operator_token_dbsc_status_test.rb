# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_dbsc_statuses
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorTokenDbscStatusTest < ActiveSupport::TestCase
  test "constants are defined correctly" do
    assert_equal 0, OperatorTokenDbscStatus::NOTHING
    assert_equal 1, OperatorTokenDbscStatus::ACTIVE
    assert_equal 2, OperatorTokenDbscStatus::PENDING
    assert_equal 3, OperatorTokenDbscStatus::FAILED
    assert_equal 4, OperatorTokenDbscStatus::REVOKE
    assert_equal [0, 1, 2, 3, 4], OperatorTokenDbscStatus::DEFAULTS
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      OperatorTokenDbscStatus.where(id: OperatorTokenDbscStatus::DEFAULTS).destroy_all
    end

    OperatorTokenDbscStatus.ensure_defaults!

    assert OperatorTokenDbscStatus.exists?(id: OperatorTokenDbscStatus::NOTHING)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    OperatorTokenDbscStatus.ensure_defaults!
    initial_count = OperatorTokenDbscStatus.count

    OperatorTokenDbscStatus.ensure_defaults!

    assert_equal initial_count, OperatorTokenDbscStatus.count
  end

  test "has_many operator_tokens association" do
    status = OperatorTokenDbscStatus.new(id: 1)

    assert_respond_to status, :operator_tokens
  end
end
