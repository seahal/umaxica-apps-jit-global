# frozen_string_literal: true

class OperatorVisaSensitiveAdmission < OpBaseOrgRecord
  STATUSES = ClientVisaSensitiveAdmission::STATUSES
  PUBLIC_REF_PATTERN = ClientVisaSensitiveAdmission::PUBLIC_REF_PATTERN
  DIGEST_PATTERN = ClientVisaSensitiveAdmission::DIGEST_PATTERN

  def self.connection_owner = OpBaseOrgRecord

  public_class_method :connection_owner

  belongs_to :oidc_authorization_transaction, class_name: "OperatorOidcAuthorizationTransaction"
  belongs_to :step_up_ceremony_transaction, class_name: "OperatorStepUpCeremonyTransaction"
  belongs_to :auth_admission_binding, class_name: "OperatorAuthAdmissionBinding"

  validates :public_ref, :realm, :client_id, :actor_subject, :grant_sid, :rp_session_ref,
            :browser_binding_digest, :purpose, :provider, :event_jti, :event_auth_time,
            :event_acr, :event_amr, :status, :expires_at, :rp_session_expires_at, presence: true
  validates :public_ref, format: { with: PUBLIC_REF_PATTERN }, uniqueness: true
  validates :public_ref, length: { maximum: 21 }
  validates :realm, inclusion: { in: ["org"] }
  validates :realm, length: { maximum: 3 }
  validates :client_id, inclusion: { in: ["base-org-ww"] }
  validates :client_id, length: { maximum: 64 }
  validates :actor_subject, length: { maximum: 255 }
  validates :grant_sid, :rp_session_ref, length: { maximum: 64 }
  validates :purpose, length: { maximum: 32 }
  validates :provider, length: { maximum: 16 }
  validates :purpose, inclusion: { in: ["passkey_registration"] }
  validates :provider, inclusion: { in: ["none"] }
  validates :browser_binding_digest, format: { with: DIGEST_PATTERN }
  validates :browser_binding_digest, length: { maximum: 64 }
  validates :event_jti, length: { maximum: 255 }
  validates :status, length: { maximum: 24 }
  validates :event_auth_time, numericality: { only_integer: true, greater_than: 0 }
  validates :event_acr, length: { minimum: 1, maximum: 64 }
  validates :status, inclusion: { in: STATUSES }
  validate :event_amr_contains_methods
  validate :expiry_follows_creation
  validate :expiry_does_not_outlive_rp_session

  private

  def event_amr_contains_methods
    return if event_amr.is_a?(Array) && event_amr.any? &&
      event_amr.all? { |method| method.is_a?(String) && method.present? }

    errors.add(:event_amr, :invalid)
  end

  def expiry_follows_creation
    return if expires_at && created_at && expires_at > created_at

    errors.add(:expires_at, :invalid)
  end

  def expiry_does_not_outlive_rp_session
    return if expires_at && rp_session_expires_at && expires_at <= rp_session_expires_at

    errors.add(:expires_at, :invalid)
  end
end
