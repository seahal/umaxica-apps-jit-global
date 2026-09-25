# typed: false
# == Schema Information
#
# Table name: avatar_blocks
# Database name: avatar
#
#  id                :bigint           not null, primary key
#  expires_at        :datetime
#  reason            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  blocked_avatar_id :bigint           not null
#  blocker_avatar_id :bigint           not null
#
# Indexes
#
#  index_avatar_blocks_on_blocked_avatar_id  (blocked_avatar_id)
#  index_avatar_blocks_on_blocker_avatar_id  (blocker_avatar_id)
#
# Foreign Keys
#
#  fk_rails_...  (blocked_avatar_id => avatars.id) ON DELETE => cascade
#  fk_rails_...  (blocker_avatar_id => avatars.id) ON DELETE => cascade
#

# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarBlockTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(
      handle: "block-test-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
  end

  test "class is defined" do
    assert_equal "AvatarBlock", AvatarBlock.name
  end

  test "rejects self block" do
    avatar = create_avatar("Self Block")
    block = AvatarBlock.new(blocker_avatar: avatar, blocked_avatar: avatar)

    assert_not block.valid?
    assert_not_empty block.errors[:blocked_avatar_id]
  end

  test "validates directed pair uniqueness" do
    blocker = create_avatar("Blocker")
    blocked = create_avatar("Blocked")

    AvatarBlock.create!(blocker_avatar: blocker, blocked_avatar: blocked)
    duplicate = AvatarBlock.new(blocker_avatar: blocker, blocked_avatar: blocked)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:blocked_avatar_id]
  end

  test "database check constraint rejects self block" do
    avatar = create_avatar("DB Self Block")
    block = AvatarBlock.new(blocker_avatar: avatar, blocked_avatar: avatar)

    assert_raises(ActiveRecord::StatementInvalid) do
      block.save(validate: false)
    end
  end

  test "database unique index rejects duplicate block pair" do
    blocker = create_avatar("DB Blocker")
    blocked = create_avatar("DB Blocked")

    AvatarBlock.create!(blocker_avatar: blocker, blocked_avatar: blocked)
    duplicate = AvatarBlock.new(blocker_avatar: blocker, blocked_avatar: blocked)

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  test "incoming block association works" do
    blocker = create_avatar("Incoming Blocker")
    blocked = create_avatar("Incoming Blocked")

    blocker.outgoing_blocks.create!(blocked_avatar: blocked)

    assert_includes blocked.incoming_blocks.map(&:blocker_avatar), blocker
    assert_includes blocked.blocking_avatars, blocker
  end

  test "block creation does not destroy follow state" do
    blocker = create_avatar("Block Follow")
    target = create_avatar("Block Target")
    blocker.outgoing_follows.create!(followed_avatar: target)

    blocker.outgoing_blocks.create!(blocked_avatar: target)

    assert_includes blocker.followings, target
    assert_includes target.followers, blocker
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
