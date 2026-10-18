# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"
# require "helpers/global_test_support"

class AvatarMutePolicyTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(handle: "policy-mute-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "create allows muting another avatar" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    record = AvatarMute.new(muter_avatar: actor, muted_avatar: target)

    assert_predicate AvatarMutePolicy.new(record, user: actor), :create?
  end

  test "create denies self mute" do
    actor = create_avatar("Actor")
    record = AvatarMute.new(muter_avatar: actor, muted_avatar: actor)

    assert_not AvatarMutePolicy.new(record, user: actor).create?
  end

  test "destroy allows muter owner" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    record = AvatarMute.create!(muter_avatar: actor, muted_avatar: target)

    assert_predicate AvatarMutePolicy.new(record, user: actor), :destroy?
  end

  test "destroy denies non muter" do
    actor = create_avatar("Actor")
    target = create_avatar("Target")
    other = create_avatar("Other")
    record = AvatarMute.create!(muter_avatar: actor, muted_avatar: target)

    assert_not AvatarMutePolicy.new(record, user: other).destroy?
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(moniker: moniker, capability: @capability, active_handle: @handle)
  end
end
