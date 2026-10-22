# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrganizationStatusTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "constants are defined" do
    assert_equal 1, OrganizationStatus::NOTHING
  end
end
