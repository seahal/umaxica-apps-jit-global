# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_membership_revoke_reasons
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AgentMembershipRevokeReasonTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, AgentMembershipRevokeReason::NOTHING
    assert_equal 1, AgentMembershipRevokeReason::MANUAL
    assert_equal 2, AgentMembershipRevokeReason::EXPIRED
    assert_equal 3, AgentMembershipRevokeReason::POLICY
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3], AgentMembershipRevokeReason::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal AgentMembershipRevokeReason::NOTHING, AgentMembershipRevokeReason.nothing_id
  end

  test "has many agent_memberships" do
    assert_equal :has_many, AgentMembershipRevokeReason.reflect_on_association(:agent_memberships).macro
  end
end
