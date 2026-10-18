# typed: false
# frozen_string_literal: true

class OpOrgLogoutReceipt < OpBaseOrgRecord
  self.table_name = "logout_receipts"

  belongs_to :logout_flow, class_name: "OpOrgLogoutFlow", inverse_of: :receipts

  validates :public_id, :nonce_digest, :browser_binding_digest, :expires_at, presence: true
end
