# frozen_string_literal: true
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


class AvatarBlock < AvatarRecord
  belongs_to :blocker_avatar,
             class_name: "Avatar",
             inverse_of: :outgoing_blocks
  belongs_to :blocked_avatar,
             class_name: "Avatar",
             inverse_of: :incoming_blocks

  validates :blocked_avatar_id, uniqueness: { scope: :blocker_avatar_id }
  validate :blocker_and_blocked_must_differ

  private

  def blocker_and_blocked_must_differ
    return if blocker_avatar_id.blank? || blocked_avatar_id.blank?
    return if blocker_avatar_id != blocked_avatar_id

    errors.add(:blocked_avatar_id, "must differ from blocker_avatar_id")
  end
end
