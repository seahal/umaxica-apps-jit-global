# frozen_string_literal: true

require "test_helper"

class AuthorityResourceLifecyclePublicPredicatesTest < ActiveSupport::TestCase
  test "APP enterprise lifecycle reports active and inactive states" do
    active = EnterpriseLifecycle.new(state: AuthorityResourceLifecycleStateValue::ACTIVE)
    inactive = EnterpriseLifecycle.new(state: AuthorityResourceLifecycleStateValue::INACTIVE)

    assert_predicate active, :active?
    assert_not inactive.active?
  end

  test "ORG agent lifecycle reports active and inactive states" do
    active = AgentLifecycle.new(state: AuthorityResourceLifecycleStateValue::ACTIVE)
    inactive = AgentLifecycle.new(state: AuthorityResourceLifecycleStateValue::INACTIVE)

    assert_predicate active, :active?
    assert_not inactive.active?
  end

  test "ORG bureau lifecycle reports active and inactive states" do
    active = BureauLifecycle.new(state: AuthorityResourceLifecycleStateValue::ACTIVE)
    inactive = BureauLifecycle.new(state: AuthorityResourceLifecycleStateValue::INACTIVE)

    assert_predicate active, :active?
    assert_not inactive.active?
  end

  test "unsaved authority cutover markers remain writable until established" do
    app_marker = EnterpriseAuthorityCutover.new
    agent_marker = AgentAuthorityCutover.new
    bureau_marker = BureauAuthorityCutover.new

    assert_not app_marker.readonly?
    assert_not agent_marker.readonly?
    assert_not bureau_marker.readonly?
  end
end
