# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_membership_states
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class IndividualMembershipStateTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, IndividualMembershipState::NOTHING
    assert_equal 1, IndividualMembershipState::ACTIVE
    assert_equal 2, IndividualMembershipState::PENDING
    assert_equal 3, IndividualMembershipState::SUSPENDED
    assert_equal 4, IndividualMembershipState::REVOKED
    assert_equal 5, IndividualMembershipState::ENDED
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3, 4, 5], IndividualMembershipState::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal IndividualMembershipState::NOTHING, IndividualMembershipState.nothing_id
  end

  test "has many individual_memberships" do
    assert_equal :has_many, IndividualMembershipState.reflect_on_association(:individual_memberships).macro
  end
end
