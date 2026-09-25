# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarSocialGraphBlockTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "social-block-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "can block another avatar" do
    actor = create_avatar("Blocker")
    target = create_avatar("Blocked")

    block = AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: target)

    assert_equal target, block.blocked_avatar
    assert_includes actor.blocked_avatars, target
  end

  test "cannot block self" do
    actor = create_avatar("Self")

    assert_raises(AvatarSocialGraph::SelfEdgeError) do
      AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: actor)
    end
  end

  test "block is idempotent when already blocked" do
    actor = create_avatar("Existing Blocker")
    target = create_avatar("Existing Blocked")
    existing = actor.outgoing_blocks.create!(blocked_avatar: target)

    block = AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: target)

    assert_equal existing.id, block.id
  end

  test "block terminates actor to target follow" do
    actor = create_avatar("Follow Blocker")
    target = create_avatar("Follow Blocked")
    actor.outgoing_follows.create!(followed_avatar: target)

    AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes actor.followings, target
  end

  test "block terminates target to actor follow" do
    actor = create_avatar("Followed Blocker")
    target = create_avatar("Followed Blocked")
    target.outgoing_follows.create!(followed_avatar: actor)

    AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes target.followings, actor
  end

  test "block does not remove mute" do
    actor = create_avatar("Mute Blocker")
    target = create_avatar("Mute Blocked")
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Block.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.muted_avatars, target
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
