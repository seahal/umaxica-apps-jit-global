# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_membership_states
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class PersonaMembershipStateTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, PersonaMembershipState::NOTHING
    assert_equal 1, PersonaMembershipState::ACTIVE
    assert_equal 2, PersonaMembershipState::PENDING
    assert_equal 3, PersonaMembershipState::SUSPENDED
    assert_equal 4, PersonaMembershipState::REVOKED
    assert_equal 5, PersonaMembershipState::ENDED
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3, 4, 5], PersonaMembershipState::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal PersonaMembershipState::NOTHING, PersonaMembershipState.nothing_id
  end

  test "has many persona_memberships" do
    assert_equal :has_many, PersonaMembershipState.reflect_on_association(:persona_memberships).macro
  end
end
