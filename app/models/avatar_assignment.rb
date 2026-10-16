# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: avatar_assignments
# Database name: avatar
#
#  id         :bigint           not null, primary key
#  role       :string(50)       default("viewer"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  avatar_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_avatar_assignments_on_user_id          (user_id)
#  index_avatar_assignments_unique              (avatar_id,user_id,role) UNIQUE
#  index_avatar_assignments_unique_affiliation  (avatar_id) UNIQUE WHERE ((role)::text = 'affiliation'::text)
#  index_avatar_assignments_unique_owner        (avatar_id) UNIQUE WHERE ((role)::text = 'owner'::text)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id) ON DELETE => cascade
#

class AvatarAssignment < AvatarRecord
  include AvatarAssignmentAuthorityProtection

  ROLES = %w(owner affiliation administrator editor reviewer viewer).freeze

  belongs_to :avatar
  belongs_to :user, class_name: "Client"

  validates :role, presence: true, inclusion: { in: ROLES }, length: { maximum: 50 }
  validates :avatar_id, length: { maximum: 255 }
  validates :avatar_id, uniqueness: { scope: [:user_id, :role] }

  validates :avatar_id,
            uniqueness: { conditions: -> { where("((role)::text = 'owner'::text)") } },
            if: -> { role == "owner" }

  validates :avatar_id,
            uniqueness: { conditions: -> { where("((role)::text = 'affiliation'::text)") } },
            if: -> { role == "affiliation" }
end
