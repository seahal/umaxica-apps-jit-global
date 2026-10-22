# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_membership_revoke_reasons
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class PersonaMembershipRevokeReasonTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, PersonaMembershipRevokeReason::NOTHING
    assert_equal 1, PersonaMembershipRevokeReason::MANUAL
    assert_equal 2, PersonaMembershipRevokeReason::EXPIRED
    assert_equal 3, PersonaMembershipRevokeReason::POLICY
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3], PersonaMembershipRevokeReason::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal PersonaMembershipRevokeReason::NOTHING, PersonaMembershipRevokeReason.nothing_id
  end

  test "has many persona_memberships" do
    assert_equal :has_many, PersonaMembershipRevokeReason.reflect_on_association(:persona_memberships).macro
  end
end
