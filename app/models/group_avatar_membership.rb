# typed: false
# frozen_string_literal: true

class GroupAvatarMembership < AvatarRecord
  include PublicId

  STATES = %w(active removed).freeze
  ROLE = "member"

  belongs_to :avatar_group, inverse_of: :group_avatar_memberships
  belongs_to :avatar, inverse_of: :group_avatar_memberships

  validates :role, inclusion: { in: [ROLE] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :state, inclusion: { in: STATES }
  validates :avatar_id, uniqueness: { scope: :avatar_group_id, conditions: -> { where(removed_at: nil) } }
  validate :removed_at_not_before_assigned_at
  validate :removed_timestamp_matches_state

  before_validation :default_assigned_at, on: :create

  scope :active, -> { where(state: "active", removed_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  def active?
    state == "active" && removed_at.blank?
  end

  private

  def default_assigned_at
    self.assigned_at ||= Time.current
  end

  def removed_at_not_before_assigned_at
    return if removed_at.blank? || assigned_at.blank? || removed_at >= assigned_at

    errors.add(:removed_at, :invalid)
  end

  def removed_timestamp_matches_state
    errors.add(:removed_at, :blank) if state == "removed" && removed_at.blank?
    errors.add(:removed_at, :present) if state == "active" && removed_at.present?
  end
end
