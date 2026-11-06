# frozen_string_literal: true

class OperatorSensitiveAdmission < OpBaseOrgRecord
  include SensitiveAdmission

  validates :public_ref, :actor_subject, :grant_sid, :rp_session_ref, :event_jti, :issued_at, :expires_at,
            presence: true
  validates :secret_digest, :browser_binding_digest, :purpose, :provider, presence: true
  validates :public_ref, format: { with: /\A[A-Za-z0-9_-]{21}\z/ }
  validates :public_ref, length: { maximum: 21 }
  validates :secret_digest, :browser_binding_digest, format: { with: DIGEST_PATTERN }
  validates :secret_digest, :browser_binding_digest, length: { maximum: 64 }
  validates :event_auth_time, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :realm, length: { maximum: 3 }
  validates :client_id, length: { maximum: 64 }
  validates :actor_subject, length: { maximum: 255 }
  validates :grant_sid, :rp_session_ref, length: { maximum: 64 }
  validates :purpose, length: { maximum: 32 }
  validates :provider, length: { maximum: 16 }
  validates :event_jti, length: { maximum: 255 }
  validates :status, length: { maximum: 16 }
  validate :valid_sensitive_admission_deadline

  validates :realm, inclusion: { in: ["org"] }
  validates :client_id, inclusion: { in: ["base-org-ww"] }
  validate :valid_purpose_provider

  private

  def valid_purpose_provider
    accepted = [["passkey_registration", "none"]]
    errors.add(:purpose, :invalid) unless accepted.include?([purpose, provider])
  end
end
