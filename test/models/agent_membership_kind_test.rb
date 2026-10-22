# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_membership_kinds
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AgentMembershipKindTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, AgentMembershipKind::NOTHING
    assert_equal 1, AgentMembershipKind::OWNER
    assert_equal 2, AgentMembershipKind::MEMBER
    assert_equal 3, AgentMembershipKind::GUEST
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3], AgentMembershipKind::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal AgentMembershipKind::NOTHING, AgentMembershipKind.nothing_id
  end

  test "has many agent_memberships" do
    assert_equal :has_many, AgentMembershipKind.reflect_on_association(:agent_memberships).macro
  end
end
