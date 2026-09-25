# typed: false
# frozen_string_literal: true

class AvatarGroup < AvatarRecord
  include PublicId

  STATES = %w(active archived).freeze
  ACCOUNT_SURFACES = %w(app org com).freeze

  has_many :group_avatar_memberships, dependent: :restrict_with_error, inverse_of: :avatar_group
  has_many :avatars, through: :group_avatar_memberships
  has_many :ownership_periods,
           class_name: "AvatarGroupOwnershipPeriod",
           dependent: :restrict_with_error,
           inverse_of: :avatar_group
  has_one :current_ownership_period,
          -> { where("valid_to = 'infinity'::timestamp with time zone") },
          class_name: "AvatarGroupOwnershipPeriod",
          inverse_of: :avatar_group

  validates :account_surface, inclusion: { in: ACCOUNT_SURFACES }
  validates :account_public_id, presence: true
  validates :name, presence: true
  validates :state, inclusion: { in: STATES }
  validate :archive_timestamp_matches_state

  scope :active, -> { where(state: "active", archived_at: nil) }

  def active?
    state == "active" && archived_at.blank?
  end

  def archived?
    state == "archived" && archived_at.present?
  end

  private

  def archive_timestamp_matches_state
    errors.add(:archived_at, :blank) if state == "archived" && archived_at.blank?
    errors.add(:archived_at, :present) if state == "active" && archived_at.present?
  end
end
