# frozen_string_literal: true
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


class AvatarFollow < AvatarRecord
  belongs_to :follower_avatar,
             class_name: "Avatar",
             inverse_of: :outgoing_follows
  belongs_to :followed_avatar,
             class_name: "Avatar",
             inverse_of: :incoming_follows

  validates :followed_avatar_id, uniqueness: { scope: :follower_avatar_id }
  validate :follower_and_followed_must_differ

  private

  def follower_and_followed_must_differ
    return if follower_avatar_id.blank? || followed_avatar_id.blank?
    return if follower_avatar_id != followed_avatar_id

    errors.add(:followed_avatar_id, "must differ from follower_avatar_id")
  end
end
