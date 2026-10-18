# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarSocialGraphFollowTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "social-follow-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "can follow another avatar" do
    actor = create_avatar("Follower")
    target = create_avatar("Followed")

    follow = AvatarSocialGraph::Follow.call(actor_avatar: actor, target_avatar: target)

    assert_equal target, follow.followed_avatar
    assert_includes actor.followings, target
  end

  test "cannot follow self" do
    actor = create_avatar("Self")

    assert_raises(AvatarSocialGraph::SelfEdgeError) do
      AvatarSocialGraph::Follow.call(actor_avatar: actor, target_avatar: actor)
    end
  end

  test "follow is idempotent when already following" do
    actor = create_avatar("Old Follower")
    target = create_avatar("Old Followed")
    existing = actor.outgoing_follows.create!(followed_avatar: target)

    follow = AvatarSocialGraph::Follow.call(actor_avatar: actor, target_avatar: target)

    assert_equal existing.id, follow.id
    assert_equal 1, AvatarFollow.where(follower_avatar_id: actor.id, followed_avatar_id: target.id).count
  end

  test "cannot follow an avatar that blocked actor" do
    actor = create_avatar("Blocked Actor")
    target = create_avatar("Blocking Target")
    target.outgoing_blocks.create!(blocked_avatar: actor)

    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Follow.call(actor_avatar: actor, target_avatar: target)
    end
  end

  test "cannot follow an avatar actor has blocked" do
    actor = create_avatar("Blocking Actor")
    target = create_avatar("Blocked Target")
    actor.outgoing_blocks.create!(blocked_avatar: target)

    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Follow.call(actor_avatar: actor, target_avatar: target)
    end
  end

  test "mute does not prevent follow" do
    actor = create_avatar("Muted Follower")
    target = create_avatar("Muted Followed")
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Follow.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.followings, target
    assert_includes actor.muted_avatars, target
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
