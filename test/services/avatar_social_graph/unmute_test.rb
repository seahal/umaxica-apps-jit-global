# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarSocialGraphUnmuteTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "social-unmute-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "can unmute" do
    actor = create_avatar("Muter")
    target = create_avatar("Muted")
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Unmute.call(actor_avatar: actor, target_avatar: target)

    assert_not_includes actor.muted_avatars, target
  end

  test "unmute is idempotent when no active mute exists" do
    actor = create_avatar("No Mute")
    target = create_avatar("No Target")

    assert_nil AvatarSocialGraph::Unmute.call(actor_avatar: actor, target_avatar: target)
  end

  test "unmute does not remove follow" do
    actor = create_avatar("Follow Owner")
    target = create_avatar("Follow Target")
    actor.outgoing_follows.create!(followed_avatar: target)
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Unmute.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.followings, target
  end

  test "unmute does not remove block" do
    actor = create_avatar("Block Owner")
    target = create_avatar("Block Target")
    actor.outgoing_blocks.create!(blocked_avatar: target)
    actor.outgoing_mutes.create!(muted_avatar: target)

    AvatarSocialGraph::Unmute.call(actor_avatar: actor, target_avatar: target)

    assert_includes actor.blocked_avatars, target
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
