# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_telephone_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorTelephoneStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, VisitorTelephoneStatus::UNVERIFIED
    assert_equal 2, VisitorTelephoneStatus::VERIFIED
    assert_equal 3, VisitorTelephoneStatus::SUSPENDED
    assert_equal 4, VisitorTelephoneStatus::DELETED
    assert_equal 5, VisitorTelephoneStatus::NOTHING
    assert_equal 6, VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
    assert_equal 7, VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP
  end

  test "defaults are defined" do
    expected = [1, 2, 3, 4, 5, 6, 7]

    assert_equal expected, VisitorTelephoneStatus::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal VisitorTelephoneStatus::NOTHING, VisitorTelephoneStatus.nothing_id
  end

  test "has many visitor_telephones" do
    assert_equal :has_many, VisitorTelephoneStatus.reflect_on_association(:visitor_telephones).macro
  end
end
