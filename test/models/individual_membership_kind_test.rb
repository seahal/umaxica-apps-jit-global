# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_membership_kinds
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class IndividualMembershipKindTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, IndividualMembershipKind::NOTHING
    assert_equal 1, IndividualMembershipKind::OWNER
    assert_equal 2, IndividualMembershipKind::MEMBER
    assert_equal 3, IndividualMembershipKind::GUEST
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2, 3], IndividualMembershipKind::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal IndividualMembershipKind::NOTHING, IndividualMembershipKind.nothing_id
  end

  test "has many individual_memberships" do
    assert_equal :has_many, IndividualMembershipKind.reflect_on_association(:individual_memberships).macro
  end
end
