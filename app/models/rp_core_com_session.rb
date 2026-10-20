# typed: false
# frozen_string_literal: true

class RpCoreComSession < RpCoreComRecord
  self.table_name = "rp_sessions"

  CELL = RpCellBinding.fetch("rp_core_com")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId

  belongs_to :op_session_binding, class_name: "RpCoreComOpSessionBinding", inverse_of: :sessions
  has_many :refresh_attempts, class_name: "RpCoreComRefreshAttempt", foreign_key: :session_id,
                              inverse_of: :session,
                              dependent: :restrict_with_error

  # The partial index counts every unrevoked row, including an expired one.
  validates :op_session_binding_id,
            uniqueness: { conditions: -> { where(revoked_at: nil) } },
            on: :create, if: -> { revoked_at.nil? }

  validates :absolute_expires_at, :contract_epoch, presence: true
  validates :installed_generation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :contract_epoch, numericality: { only_integer: true, greater_than: 0 }
  validate :identity_binding_must_be_resolved
  validates :current_access_jti_digest, length: { maximum: 64 }

  public

  def active?(now: Time.current)
    revoked_at.nil? && op_session_binding&.revoked_at.nil? && absolute_expires_at.present? && absolute_expires_at > now
  end

  private

  def identity_binding_must_be_resolved
    return if op_session_binding&.identity_binding_id.present?

    errors.add(:op_session_binding, "must have a resolved identity binding")
  end
end
