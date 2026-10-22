# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: division_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class DivisionStatusTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "constants are defined" do
    assert_equal 1, DivisionStatus::NOTHING
    assert_equal 2, DivisionStatus::ACTIVE
    assert_equal 3, DivisionStatus::INACTIVE
    assert_equal 4, DivisionStatus::DELETED
  end
end
