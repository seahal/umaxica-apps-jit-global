# typed: false
# frozen_string_literal: true

class OpComLogoutReceipt < OpBaseComRecord
  self.table_name = "logout_receipts"

  belongs_to :logout_flow, class_name: "OpComLogoutFlow", inverse_of: :receipts

  validates :public_id, :nonce_digest, :browser_binding_digest, :expires_at, presence: true
  validates :public_id, length: { maximum: 21 }
end
