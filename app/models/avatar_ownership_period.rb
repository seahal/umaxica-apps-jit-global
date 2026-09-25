# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_ownership_periods
# Database name: avatar
#
#  id                         :bigint           not null, primary key
#  valid_from                 :datetime         not null
#  valid_to                   :datetime         default(Infinity), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  avatar_id                  :bigint           not null
#  avatar_ownership_status_id :bigint
#  owner_organization_id      :string           not null
#  transferred_by_actor_id    :bigint
#
# Indexes
#
#  idx_avatar_ownership_periods_avatar_id_all_rows               (avatar_id)
#  index_avatar_ownership_periods_on_avatar_id                   (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_ownership_periods_on_avatar_ownership_status_id  (avatar_ownership_status_id)
#  index_avatar_ownership_periods_on_owner_organization_id       (owner_organization_id) WHERE (valid_to = 'infinity'::timestamp with time zone)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (avatar_ownership_status_id => avatar_ownership_statuses.id)
#

class AvatarOwnershipPeriod < AvatarRecord
  self.belongs_to_required_by_default = false

  belongs_to :avatar
  belongs_to :avatar_ownership_status

  OWNER_SURFACES = %w(app org).freeze

  scope :current, -> { where("valid_to = 'infinity'::timestamp with time zone") }

  validates :avatar_id,
            uniqueness: { conditions: -> { where("valid_to = 'infinity'::timestamp with time zone") } }
  validates :owner_surface, inclusion: { in: OWNER_SURFACES }
  validates :owner_collective_public_id, presence: true
  validates :avatar_ownership_status_id, presence: true
  validates :valid_from, presence: true
  validates :id, length: { maximum: 255 }

  def current?
    valid_to == Float::INFINITY && avatar_ownership_status_id == AvatarOwnershipStatus::ACTIVE
  end
end
