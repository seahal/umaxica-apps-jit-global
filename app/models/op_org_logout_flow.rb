# typed: false
# frozen_string_literal: true

class OpOrgLogoutFlow < OpBaseOrgRecord
  self.table_name = "logout_flows"

  REALM = "org"

  has_many :participants, class_name: "OpOrgLogoutFlowParticipant", foreign_key: :logout_flow_id,
                          inverse_of: :logout_flow,
                          dependent: :restrict_with_exception
  has_many :receipts, class_name: "OpOrgLogoutReceipt", foreign_key: :logout_flow_id,
                      inverse_of: :logout_flow,
                      dependent: :restrict_with_exception

  validates :public_id, :realm, :target_root_ref, :idempotency_digest, :browser_binding_digest,
            :expires_at, :audit_ref, presence: true
  validates :realm, inclusion: { in: [REALM] }
end
