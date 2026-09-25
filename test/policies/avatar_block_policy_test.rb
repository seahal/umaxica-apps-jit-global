# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarBlockPolicyTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "policy-block-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "create allows blocking another avatar" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    record = AvatarBlock.new(blocker_avatar: actor, blocked_avatar: target)

    assert_predicate AvatarBlockPolicy.new(record, user: actor), :create?
  end

  test "create denies self block" do
    actor = create_avatar("Actor")
    record = AvatarBlock.new(blocker_avatar: actor, blocked_avatar: actor)

    assert_not AvatarBlockPolicy.new(record, user: actor).create?
  end

  test "destroy allows blocker owner" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    record = AvatarBlock.create!(blocker_avatar: actor, blocked_avatar: target)

    assert_predicate AvatarBlockPolicy.new(record, user: actor), :destroy?
  end

  test "destroy denies non blocker" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    other = create_avatar("Other")
    record = AvatarBlock.create!(blocker_avatar: actor, blocked_avatar: target)

    assert_not AvatarBlockPolicy.new(record, user: other).destroy?
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
