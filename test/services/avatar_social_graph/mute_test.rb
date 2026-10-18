# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarSocialGraphMuteTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "social-mute-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "can mute another avatar" do
    actor = create_avatar("Muter")
    target = create_avatar("Muted")

    mute = AvatarSocialGraph::Mute.call(actor_avatar: actor, target_avatar: target)

    assert_equal target, mute.muted_avatar
    assert_includes actor.muted_avatars, target
  end

  test "cannot mute self" do
    actor = create_avatar("Self")

    assert_raises(AvatarSocialGraph::SelfEdgeError) do
      AvatarSocialGraph::Mute.call(actor_avatar: actor, target_avatar: actor)
    end
  end

  test "mute is idempotent when already muted" do
    actor = create_avatar("Existing Muter")
    target = create_avatar("Existing Muted")
    existing = actor.outgoing_mutes.create!(muted_avatar: target)

    mute = AvatarSocialGraph::Mute.call(actor_avatar: actor, target_avatar: target)

    assert_equal existing.id, mute.id
  end

  test "mute does not remove follow" do
    actor = create_avatar("Follow Owner")
    target = create_avatar("Follow Target")
    actor.outgoing_follows.create!(followed_avatar: target)

    AvatarSocialGraph::Mute.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.followings, target
  end

  test "mute does not create or remove block" do
    actor = create_avatar("Block Owner")
    target = create_avatar("Block Target")

    AvatarSocialGraph::Mute.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes actor.blocked_avatars, target
    assert_not_includes target.blocking_avatars, actor
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
