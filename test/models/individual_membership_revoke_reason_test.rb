# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_membership_revoke_reasons
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class IndividualMembershipRevokeReasonTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, IndividualMembershipRevokeReason::NOTHING
    assert_equal 1, IndividualMembershipRevokeReason::MANUAL
    assert_equal 2, IndividualMembershipRevokeReason::EXPIRED
    assert_equal 3, IndividualMembershipRevokeReason::POLICY
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3], IndividualMembershipRevokeReason::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal IndividualMembershipRevokeReason::NOTHING, IndividualMembershipRevokeReason.nothing_id
  end

  test "has many individual_memberships" do
    assert_equal :has_many, IndividualMembershipRevokeReason.reflect_on_association(:individual_memberships).macro
  end
end
