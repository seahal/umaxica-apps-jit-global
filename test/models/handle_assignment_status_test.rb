# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handle_assignment_statuses
# Database name: avatar
#
#  id :bigint           not null, primary key
#

require "test_helper"

class HandleAssignmentStatusTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 1, HandleAssignmentStatus::INACTIVE
    assert_equal 2, HandleAssignmentStatus::PENDING
    assert_equal 3, HandleAssignmentStatus::ACTIVE
    assert_equal 4, HandleAssignmentStatus::DELETED
    assert_equal 5, HandleAssignmentStatus::NOTHING
  end
end
