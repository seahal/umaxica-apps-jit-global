# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_membership_states
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AgentMembershipStateTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, AgentMembershipState::NOTHING
    assert_equal 1, AgentMembershipState::ACTIVE
    assert_equal 2, AgentMembershipState::PENDING
    assert_equal 3, AgentMembershipState::SUSPENDED
    assert_equal 4, AgentMembershipState::REVOKED
    assert_equal 5, AgentMembershipState::ENDED
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3, 4, 5], AgentMembershipState::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal AgentMembershipState::NOTHING, AgentMembershipState.nothing_id
  end

  test "has many agent_memberships" do
    assert_equal :has_many, AgentMembershipState.reflect_on_association(:agent_memberships).macro
  end
end
