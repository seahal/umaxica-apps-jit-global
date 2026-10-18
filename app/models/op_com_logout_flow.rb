# typed: false
# frozen_string_literal: true

class OpComLogoutFlow < OpBaseComRecord
  self.table_name = "logout_flows"

  REALM = "com"

  has_many :participants, class_name: "OpComLogoutFlowParticipant", foreign_key: :logout_flow_id,
                          inverse_of: :logout_flow,
                          dependent: :restrict_with_exception
  has_many :receipts, class_name: "OpComLogoutReceipt", foreign_key: :logout_flow_id,
                      inverse_of: :logout_flow,
                      dependent: :restrict_with_exception

  validates :public_id, :realm, :target_root_ref, :idempotency_digest, :browser_binding_digest,
            :expires_at, :audit_ref, presence: true
  validates :realm, inclusion: { in: [REALM] }
end
