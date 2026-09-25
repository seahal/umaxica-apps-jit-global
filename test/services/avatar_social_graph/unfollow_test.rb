# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarSocialGraphUnfollowTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "social-unfollow-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "can unfollow an active follow" do
    actor = create_avatar("Follower")
    target = create_avatar("Followed")
    actor.outgoing_follows.create!(followed_avatar: target)

    AvatarSocialGraph::Unfollow.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes actor.followings, target
  end

  test "unfollow is idempotent when no active follow exists" do
    actor = create_avatar("No Follow")
    target = create_avatar("No Target")

    assert_nil AvatarSocialGraph::Unfollow.call(actor_avatar: actor, target_avatar: target)
  end

  test "unfollow does not remove mute" do
    actor = create_avatar("Mute Owner")
    target = create_avatar("Mute Target")
    actor.outgoing_follows.create!(followed_avatar: target)
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Unfollow.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.muted_avatars, target
  end

  test "unfollow does not remove block" do
    actor = create_avatar("Block Owner")
    target = create_avatar("Block Target")
    actor.outgoing_follows.create!(followed_avatar: target)
    actor.outgoing_blocks.create!(blocked_avatar: target)

    AvatarSocialGraph::Unfollow.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.blocked_avatars, target
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
