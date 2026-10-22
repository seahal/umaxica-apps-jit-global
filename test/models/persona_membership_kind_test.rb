# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_membership_kinds
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class PersonaMembershipKindTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, PersonaMembershipKind::NOTHING
    assert_equal 1, PersonaMembershipKind::OWNER
    assert_equal 2, PersonaMembershipKind::MEMBER
    assert_equal 3, PersonaMembershipKind::GUEST
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3], PersonaMembershipKind::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal PersonaMembershipKind::NOTHING, PersonaMembershipKind.nothing_id
  end

  test "has many persona_memberships" do
    assert_equal :has_many, PersonaMembershipKind.reflect_on_association(:persona_memberships).macro
  end
end
