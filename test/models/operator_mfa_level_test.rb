# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_mfa_levels
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorMfaLevelTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, OperatorMfaLevel::NOTHING
    assert_equal 1, OperatorMfaLevel::WEAK
    assert_equal 5, OperatorMfaLevel::MEDIUM
    assert_equal 9, OperatorMfaLevel::FULL
  end

  test "defaults are defined" do
    assert_equal [0, 1, 5, 9], OperatorMfaLevel::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal OperatorMfaLevel::NOTHING, OperatorMfaLevel.nothing_id
  end

  test "has many staffs" do
    assert_equal :has_many, OperatorMfaLevel.reflect_on_association(:staffs).macro
  end
end
