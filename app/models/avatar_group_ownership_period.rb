# typed: false
# frozen_string_literal: true

class AvatarGroupOwnershipPeriod < AvatarRecord
  OWNER_SURFACES = %w(app org).freeze

  belongs_to :avatar_group, inverse_of: :ownership_periods

  scope :current, -> { where("valid_to = 'infinity'::timestamp with time zone") }

  validates :avatar_group_id,
            uniqueness: { conditions: -> { where("valid_to = 'infinity'::timestamp with time zone") } }
  validates :owner_surface, inclusion: { in: OWNER_SURFACES }
  validates :owner_collective_public_id, presence: true
  validates :valid_from, presence: true

  def current?
    valid_to == Float::INFINITY
  end
end
