# typed: false
# == Schema Information
#
# Table name: avatar_mutes
# Database name: avatar
#
#  id              :bigint           not null, primary key
#  expires_at      :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  muted_avatar_id :bigint           not null
#  muter_avatar_id :bigint           not null
#
# Indexes
#
#  index_avatar_mutes_on_muted_avatar_id  (muted_avatar_id)
#  index_avatar_mutes_on_muter_avatar_id  (muter_avatar_id)
#
# Foreign Keys
#
#  fk_rails_...  (muted_avatar_id => avatars.id) ON DELETE => cascade
#  fk_rails_...  (muter_avatar_id => avatars.id) ON DELETE => cascade
#

# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarMuteTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
    @handle = Handle.create!(
      handle: "mute-test-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
  end

  test "class is defined" do
    assert_equal "AvatarMute", AvatarMute.name
  end

  test "rejects self mute" do
    avatar = create_avatar("Self Mute")
    mute = AvatarMute.new(muter_avatar: avatar, muted_avatar: avatar)

    assert_not mute.valid?
    assert_not_empty mute.errors[:muted_avatar_id]
  end

  test "validates directed pair uniqueness" do
    muter = create_avatar("Muter")
    muted = create_avatar("Muted")

    AvatarMute.create!(muter_avatar: muter, muted_avatar: muted)
    duplicate = AvatarMute.new(muter_avatar: muter, muted_avatar: muted)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:muted_avatar_id]
  end

  test "database check constraint rejects self mute" do
    avatar = create_avatar("DB Self Mute")
    mute = AvatarMute.new(muter_avatar: avatar, muted_avatar: avatar)

    assert_raises(ActiveRecord::StatementInvalid) do
      mute.save(validate: false)
    end
  end

  test "database unique index rejects duplicate mute pair" do
    muter = create_avatar("DB Muter")
    muted = create_avatar("DB Muted")

    AvatarMute.create!(muter_avatar: muter, muted_avatar: muted)
    duplicate = AvatarMute.new(muter_avatar: muter, muted_avatar: muted)

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  test "incoming mute association works" do
    muter = create_avatar("Incoming Muter")
    muted = create_avatar("Incoming Muted")

    muter.outgoing_mutes.create!(muted_avatar: muted)

    assert_includes muted.incoming_mutes.map(&:muter_avatar), muter
    assert_includes muted.muting_avatars, muter
  end

  test "mute creation does not destroy follow state" do
    muter = create_avatar("Mute Follow")
    target = create_avatar("Mute Target")
    muter.outgoing_follows.create!(followed_avatar: target)

    muter.outgoing_mutes.create!(muted_avatar: target)

    assert_includes muter.followings, target
    assert_includes target.followers, muter
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
