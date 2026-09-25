# typed: false
# == Schema Information
#
# Table name: avatar_capabilities
# Database name: avatar
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarCapabilityTest < ActiveSupport::TestCase
  setup do
    @capability = AvatarCapability.new(id: 99)
  end

  test "valid capability" do
    assert_predicate @capability, :valid?
  end

  test "association deletion: restriction by avatars" do
    @capability.save!
    handle = Handle.create!(handle: "cap_test_handle", cooldown_until: Time.current)
    AvatarTestFactory.create!(
      moniker: "Cap Test Avatar",
      active_handle: handle,
      capability: @capability,
    )

    assert_not @capability.destroy
    assert_not_empty @capability.errors[:base]
  end

  test "accepts integer ids" do
    record = AvatarCapability.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are defined" do
    assert_equal 1, AvatarCapability::NORMAL
  end
end
