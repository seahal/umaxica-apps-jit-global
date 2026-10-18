# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_statuses
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorTokenStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = VisitorTokenStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 0, VisitorTokenStatus::NOTHING
    assert_equal 1, VisitorTokenStatus::ACTIVE
    assert_equal 102, VisitorTokenStatus::EXPIRED
    assert_equal 103, VisitorTokenStatus::RESTRICTED
    assert_equal 104, VisitorTokenStatus::REVOKED
  end

  test "defaults are defined" do
    assert_equal [0, 1, 102, 103, 104], VisitorTokenStatus::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal VisitorTokenStatus::NOTHING, VisitorTokenStatus.nothing_id
  end

  test "has many visitor_tokens" do
    assert_equal :has_many, VisitorTokenStatus.reflect_on_association(:visitor_tokens).macro
  end
end
