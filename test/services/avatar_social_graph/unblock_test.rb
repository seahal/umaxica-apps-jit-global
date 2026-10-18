# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarSocialGraphUnblockTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "social-unblock-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "can unblock" do
    actor = create_avatar("Blocker")
    target = create_avatar("Blocked")
    actor.outgoing_blocks.create!(blocked_avatar: target)

    AvatarSocialGraph::Unblock.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes actor.blocked_avatars, target
  end

  test "unblock is idempotent when no active block exists" do
    actor = create_avatar("No Block")
    target = create_avatar("No Target")

    assert_nil AvatarSocialGraph::Unblock.call(actor_avatar: actor, target_avatar: target)
  end

  test "unblock does not restore prior follow state" do
    actor = create_avatar("Blocker")
    target = create_avatar("Blocked")
    actor.outgoing_follows.create!(followed_avatar: target)
    AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: target)

    AvatarSocialGraph::Unblock.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes actor.followings, target
  end

  test "unblock does not remove mute" do
    actor = create_avatar("Mute Blocker")
    target = create_avatar("Mute Blocked")
    actor.outgoing_blocks.create!(blocked_avatar: target)
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Unblock.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.muted_avatars, target
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
