# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch20PreciseServicesTest < ActiveSupport::TestCase
  def inactive_avatar
    avatar = Object.new
    state = Struct.new(:key).new("inactive")
    avatar.define_singleton_method(:lifecycle_state) { state }
    avatar.define_singleton_method(:accessible?) { false }
    avatar.define_singleton_method(:id) { 1 }
    avatar.define_singleton_method(:==) { |other| equal?(other) }
    avatar
  end

  def active_avatar(id:)
    avatar = Object.new
    state = Struct.new(:key).new("active")
    avatar.define_singleton_method(:lifecycle_state) { state }
    avatar.define_singleton_method(:accessible?) { true }
    avatar.define_singleton_method(:id) { id }
    avatar.define_singleton_method(:==) { |other| equal?(other) }
    avatar
  end

  test "avatar social graph Follow Block Mute inactive raises" do
    dead_a = inactive_avatar
    dead_b = inactive_avatar
    live = active_avatar(id: 1)
    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Follow.call(actor_avatar: dead_a, target_avatar: live)
    end
    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Follow.call(actor_avatar: live, target_avatar: dead_b)
    end
    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Block.call(actor_avatar: dead_a, target_avatar: active_avatar(id: 2))
    end
    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Block.call(actor_avatar: active_avatar(id: 3), target_avatar: dead_b)
    end
    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Mute.call(actor_avatar: dead_a, target_avatar: active_avatar(id: 4))
    end
    assert_raises(AvatarSocialGraph::BlockedError) do
      AvatarSocialGraph::Mute.call(actor_avatar: active_avatar(id: 5), target_avatar: dead_b)
    end
  end
end
