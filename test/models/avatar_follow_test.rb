# typed: false
# == Schema Information
#
# Table name: avatar_follows
# Database name: avatar
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  followed_avatar_id :bigint           not null
#  follower_avatar_id :bigint           not null
#
# Indexes
#
#  index_avatar_follows_on_followed_avatar_id  (followed_avatar_id)
#  index_avatar_follows_on_follower_avatar_id  (follower_avatar_id)
#
# Foreign Keys
#
#  fk_rails_...  (followed_avatar_id => avatars.id)
#  fk_rails_...  (follower_avatar_id => avatars.id)
#

# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarFollowTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(
      handle: "follow-test-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
  end

  test "class is defined" do
    assert_equal "AvatarFollow", AvatarFollow.name
  end

  test "rejects self follow" do
    avatar = create_avatar("Self Follow")
    follow = AvatarFollow.new(follower_avatar: avatar, followed_avatar: avatar)

    assert_not follow.valid?
    assert_not_empty follow.errors[:followed_avatar_id]
  end

  test "validates directed pair uniqueness" do
    follower = create_avatar("Follower")
    followed = create_avatar("Followed")

    AvatarFollow.create!(follower_avatar: follower, followed_avatar: followed)
    duplicate = AvatarFollow.new(follower_avatar: follower, followed_avatar: followed)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:followed_avatar_id]
  end

  test "database check constraint rejects self follow" do
    avatar = create_avatar("DB Self Follow")

    follow = AvatarFollow.new(follower_avatar: avatar, followed_avatar: avatar)

    assert_raises(ActiveRecord::StatementInvalid) do
      follow.save(validate: false)
    end
  end

  test "database unique index rejects duplicate follow pair" do
    follower = create_avatar("DB Follower")
    followed = create_avatar("DB Followed")

    AvatarFollow.create!(follower_avatar: follower, followed_avatar: followed)

    duplicate = AvatarFollow.new(follower_avatar: follower, followed_avatar: followed)

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  private

  def create_avatar(moniker)
    AvatarTestFactory.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: moniker,
    )
  end
end
