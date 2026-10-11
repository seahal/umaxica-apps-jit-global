# typed: false
# frozen_string_literal: true

class AvatarBureauOwnershipPeriod < AvatarRecord
  belongs_to :avatar, inverse_of: :bureau_ownership_periods
  has_many :agent_grants,
           class_name: "AvatarBureauAgentGrant",
           dependent: :restrict_with_error,
           inverse_of: :ownership_period

  validates :bureau_public_id, presence: true
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
