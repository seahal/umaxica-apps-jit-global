# typed: false
# frozen_string_literal: true

class AvatarEnterpriseOwnershipPeriod < AvatarRecord
  belongs_to :avatar, inverse_of: :enterprise_ownership_periods
  has_many :persona_grants,
           class_name: "AvatarEnterprisePersonaGrant",
           dependent: :restrict_with_error,
           inverse_of: :ownership_period

  validates :enterprise_public_id, presence: true
  validates :valid_from, presence: true
  validate :valid_interval

  scope :current, -> { where("valid_to = 'infinity'::timestamp with time zone") }

  public

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
