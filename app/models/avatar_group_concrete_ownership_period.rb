# typed: false
# frozen_string_literal: true

class AvatarGroupConcreteOwnershipPeriod < AvatarRecord
  OWNER_SURFACES = %w(app org).freeze

  belongs_to :avatar_group, inverse_of: :concrete_ownership_periods

  validates :avatar_group_id,
            uniqueness: { conditions: -> { where("valid_to = 'infinity'::timestamp with time zone") } }
  validates :owner_surface, inclusion: { in: OWNER_SURFACES }
  validates :owner_collective_public_id, presence: true
  validates :valid_from, presence: true

  scope :current, -> { where("valid_to = 'infinity'::timestamp with time zone") }

  public

  def current?
    valid_to == Float::INFINITY
  end
end
