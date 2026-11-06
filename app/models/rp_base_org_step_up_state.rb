# frozen_string_literal: true

class RpBaseOrgStepUpState < RpBaseOrgRecord
  self.table_name = "rp_step_up_states"

  PUBLIC_ID_LENGTH = 21
  DIGEST_FORMAT = /\A[0-9a-f]{64}\z/
  PKCE_CHALLENGE_FORMAT = /\A[A-Za-z0-9_-]{43}\z/

  belongs_to :rp_session, class_name: "RpBaseOrgSession", inverse_of: :step_up_states
  belongs_to :state, class_name: "RpBaseOrgStepUpStateStatus", inverse_of: :step_up_states

  has_many :transitions,
           class_name: "RpBaseOrgStepUpStateTransition",
           foreign_key: :owner_id,
           inverse_of: :owner,
           dependent: :restrict_with_error

  validates :public_id, :state_digest, :browser_binding_digest, :nonce_digest, :pkce_challenge, presence: true
  validates :public_id, length: { is: PUBLIC_ID_LENGTH }
  validates :state_digest, :browser_binding_digest, :nonce_digest, length: { maximum: 64 }
  validates :pkce_challenge, length: { maximum: 128 }
  validates :state_digest, :browser_binding_digest, :nonce_digest, format: { with: DIGEST_FORMAT }
  validates :pkce_challenge, format: { with: PKCE_CHALLENGE_FORMAT }
  validates :pkce_verifier_ciphertext, :issuer, :client_id, :return_target, :expires_at, presence: true
  validates :issuer, length: { maximum: 255 }
  validates :realm, inclusion: { in: ["ORG"] }
  validates :realm, length: { maximum: 3 }
  validates :client_id, inclusion: { in: ["base-org-ww"] }
  validates :client_id, length: { maximum: 64 }
  validates :return_target, length: { maximum: 512 }
  validates :initiating_generation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :return_target_is_a_same_rp_path

  private

  def return_target_is_a_same_rp_path
    return if return_target.is_a?(String) && return_target.length <= 512 &&
      RpTargetLinkUri.normalize(return_target) == return_target

    errors.add(:return_target, "must be a normalized same-RP path")
  end
end
