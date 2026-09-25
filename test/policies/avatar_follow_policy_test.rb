# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarFollowPolicyTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "policy-follow-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "create allows normal follow" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    record = AvatarFollow.new(follower_avatar: actor, followed_avatar: target)

    assert_predicate AvatarFollowPolicy.new(record, user: actor), :create?
  end

  test "create denies self follow" do
    actor = create_avatar("Actor")
    record = AvatarFollow.new(follower_avatar: actor, followed_avatar: actor)

    assert_not AvatarFollowPolicy.new(record, user: actor).create?
  end

  test "create denies follow when target blocked actor" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    target.outgoing_blocks.create!(blocked_avatar: actor)
    record = AvatarFollow.new(follower_avatar: actor, followed_avatar: target)

    assert_not AvatarFollowPolicy.new(record, user: actor).create?
  end

  test "create denies follow when actor blocked target" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    actor.outgoing_blocks.create!(blocked_avatar: target)
    record = AvatarFollow.new(follower_avatar: actor, followed_avatar: target)

    assert_not AvatarFollowPolicy.new(record, user: actor).create?
  end

  test "block precedence wins over follow" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    target.outgoing_blocks.create!(blocked_avatar: actor)
    record = AvatarFollow.new(follower_avatar: actor, followed_avatar: target)

    assert_not AvatarFollowPolicy.new(record, user: actor).create?
  end

  test "destroy allows follower owner" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    record = AvatarFollow.create!(follower_avatar: actor, followed_avatar: target)

    assert_predicate AvatarFollowPolicy.new(record, user: actor), :destroy?
  end

  test "destroy denies non follower" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    other = create_avatar("Other")
    record = AvatarFollow.create!(follower_avatar: actor, followed_avatar: target)

    assert_not AvatarFollowPolicy.new(record, user: other).destroy?
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
