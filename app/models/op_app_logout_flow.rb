# typed: false
# frozen_string_literal: true

class OpAppLogoutFlow < OpBaseAppRecord
  self.table_name = "logout_flows"

  REALM = "app"

  has_many :participants, class_name: "OpAppLogoutFlowParticipant", foreign_key: :logout_flow_id,
                          inverse_of: :logout_flow,
                          dependent: :restrict_with_exception
  has_many :receipts, class_name: "OpAppLogoutReceipt", foreign_key: :logout_flow_id,
                      inverse_of: :logout_flow,
                      dependent: :restrict_with_exception

  validates :public_id, :realm, :target_root_ref, :idempotency_digest, :browser_binding_digest,
            :expires_at, :audit_ref, presence: true
  validates :realm, inclusion: { in: [REALM] }
  validates :realm, length: { maximum: 3 }
  validates :public_id, length: { maximum: 21 }
  validates :audit_ref, length: { maximum: 128 }
  validates :target_root_ref, length: { maximum: 255 }
end
