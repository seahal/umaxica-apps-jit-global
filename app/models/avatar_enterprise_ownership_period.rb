# typed: false
# frozen_string_literal: true

class AvatarEnterpriseOwnershipPeriod < AvatarRecord
  belongs_to :avatar, inverse_of: :enterprise_ownership_periods
  has_many :persona_grants,
           class_name: "AvatarEnterprisePersonaGrant",
           dependent: :restrict_with_error,
           inverse_of: :ownership_period

  validates :enterprise_public_id, presence: true
  validates :avatar_id,
            uniqueness: { conditions: -> { where("valid_to = 'infinity'::timestamp with time zone") } },
            on: :create, if: -> { valid_to == Float::INFINITY }
  validates :valid_from, presence: true
  validate :valid_interval
  validates :enterprise_public_id, :transferred_by_actor_public_id, length: { maximum: 255 }

  scope :current, -> { where("valid_to = 'infinity'::timestamp with time zone") }

  public

  def owner_surface
    "app"
  end

  def owner_collective_public_id
    enterprise_public_id
  end

  def current?
    valid_to == Float::INFINITY
  end

  private

  def valid_interval
    return if valid_from.blank? || valid_to.blank? || valid_to == Float::INFINITY
    return if valid_from < valid_to

    errors.add(:valid_to, :greater_than, count: valid_from)
  end
end
