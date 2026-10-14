# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: member_avatar_impersonations
# Database name: avatar
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  avatar_id  :bigint           not null
#  member_id  :bigint           not null
#
# Indexes
#
#  index_member_avatar_impersonations_on_avatar_id                (avatar_id)
#  index_member_avatar_impersonations_on_member_id_and_avatar_id  (member_id,avatar_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#


class MemberAvatarImpersonation < AvatarRecord
  belongs_to :member, inverse_of: :member_avatar_impersonations
  belongs_to :avatar, inverse_of: :member_avatar_impersonations

  validates :avatar_id, uniqueness: { scope: :member_id }
end
