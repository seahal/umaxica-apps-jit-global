# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_email_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorEmailStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, VisitorEmailStatus::UNVERIFIED
    assert_equal 2, VisitorEmailStatus::VERIFIED
    assert_equal 3, VisitorEmailStatus::SUSPENDED
    assert_equal 4, VisitorEmailStatus::DELETED
    assert_equal 5, VisitorEmailStatus::NOTHING
    assert_equal 6, VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP
    assert_equal 7, VisitorEmailStatus::VERIFIED_WITH_SIGN_UP
  end

  test "defaults are defined" do
    expected = [1, 2, 3, 4, 5, 6, 7]

    assert_equal expected, VisitorEmailStatus::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal VisitorEmailStatus::NOTHING, VisitorEmailStatus.nothing_id
  end

  test "has many visitor_emails" do
    assert_equal :has_many, VisitorEmailStatus.reflect_on_association(:visitor_emails).macro
  end
end
