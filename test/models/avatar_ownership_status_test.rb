# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_ownership_statuses
# Database name: avatar
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AvatarOwnershipStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, AvatarOwnershipStatus::NOTHING
    assert_equal 2, AvatarOwnershipStatus::ACTIVE
    assert_equal 3, AvatarOwnershipStatus::INACTIVE
    assert_equal 4, AvatarOwnershipStatus::DELETED
  end
end
