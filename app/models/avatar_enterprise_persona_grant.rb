# typed: false
# frozen_string_literal: true

class AvatarEnterprisePersonaGrant < AvatarRecord
  include PublicId

  CAPABILITIES = %w(
    avatar.view
    avatar.update
    avatar.group.manage
    avatar.group.attach
    avatar.group.detach
  ).freeze

  belongs_to :ownership_period,
             class_name: "AvatarEnterpriseOwnershipPeriod",
             foreign_key: :avatar_enterprise_ownership_period_id,
             inverse_of: :persona_grants
  has_one :avatar, through: :ownership_period

  validates :persona_public_id,
            uniqueness: { scope: %i(avatar_enterprise_ownership_period_id capability),
                          conditions: -> { where(revoked_at: nil) }, },
            on: :create, if: -> { revoked_at.nil? }

  validates :persona_public_id, :capability, :granted_by_actor_public_id, :granted_by_surface, :granted_at,
            presence: true
  validates :granted_by_surface, inclusion: { in: ["app"] }
  validates :capability, inclusion: { in: CAPABILITIES }
  validates :revoked_at,
            comparison: { greater_than_or_equal_to: :granted_at },
            if: -> { granted_at.present? && revoked_at.present? }
  validates :granted_by_surface, length: { maximum: 3 }
  validates :granted_by_actor_public_id, :persona_public_id, length: { maximum: 25 }
  validates :capability, length: { maximum: 50 }

  scope :active, -> { where(revoked_at: nil) }
  scope :effective_at, ->(at) { where(granted_at: ..at).where("revoked_at IS NULL OR revoked_at > ?", at) }

  public

  def effective_at?(at = Time.current)
    granted_at <= at && (revoked_at.nil? || revoked_at > at)
  end
end
