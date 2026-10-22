# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_mfa_levels
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorMfaLevelTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, VisitorMfaLevel::NOTHING
    assert_equal 1, VisitorMfaLevel::WEAK
    assert_equal 5, VisitorMfaLevel::MEDIUM
    assert_equal 9, VisitorMfaLevel::FULL
  end

  test "defaults are defined" do
    assert_equal [0, 1, 5, 9], VisitorMfaLevel::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal VisitorMfaLevel::NOTHING, VisitorMfaLevel.nothing_id
  end

  test "has many visitors" do
    assert_equal :has_many, VisitorMfaLevel.reflect_on_association(:visitors).macro
  end
end
