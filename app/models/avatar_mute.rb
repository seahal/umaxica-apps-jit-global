# frozen_string_literal: true
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

class AvatarMute < AvatarRecord
  belongs_to :muter_avatar,
             class_name: "Avatar",
             inverse_of: :outgoing_mutes
  belongs_to :muted_avatar,
             class_name: "Avatar",
             inverse_of: :incoming_mutes

  validates :muted_avatar_id, uniqueness: { scope: :muter_avatar_id }
  validate :muter_and_muted_must_differ

  private

  def muter_and_muted_must_differ
    return if muter_avatar_id.blank? || muted_avatar_id.blank?
    return if muter_avatar_id != muted_avatar_id

    errors.add(:muted_avatar_id, "must differ from muter_avatar_id")
  end
end
