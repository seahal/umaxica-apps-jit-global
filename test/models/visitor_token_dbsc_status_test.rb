# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_dbsc_statuses
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorTokenDbscStatusTest < ActiveSupport::TestCase
  test "constants are defined correctly" do
    assert_equal 0, VisitorTokenDbscStatus::NOTHING
    assert_equal 1, VisitorTokenDbscStatus::ACTIVE
    assert_equal 2, VisitorTokenDbscStatus::PENDING
    assert_equal 3, VisitorTokenDbscStatus::FAILED
    assert_equal 4, VisitorTokenDbscStatus::REVOKE
    assert_equal [0, 1, 2, 3, 4], VisitorTokenDbscStatus::DEFAULTS
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      VisitorTokenDbscStatus.where(id: VisitorTokenDbscStatus::DEFAULTS).destroy_all
    end

    VisitorTokenDbscStatus.ensure_defaults!

    assert VisitorTokenDbscStatus.exists?(id: VisitorTokenDbscStatus::NOTHING)
    assert VisitorTokenDbscStatus.exists?(id: VisitorTokenDbscStatus::ACTIVE)
    assert VisitorTokenDbscStatus.exists?(id: VisitorTokenDbscStatus::PENDING)
  end

  test "has_many visitor_tokens association" do
    status = VisitorTokenDbscStatus.new(id: 1)

    assert_respond_to status, :visitor_tokens
  end
end
