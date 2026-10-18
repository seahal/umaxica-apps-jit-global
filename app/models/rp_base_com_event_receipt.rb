# typed: false
# frozen_string_literal: true

class RpBaseComEventReceipt < RpBaseComRecord
  self.table_name = "rp_event_receipts"

  CELL = RpCellBinding.fetch("rp_base_com")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  belongs_to :op_session_binding, class_name: "RpBaseComOpSessionBinding", inverse_of: :event_receipts

  validates :issuer, :realm, :client_id, :event_type, :jti_digest, :expires_at, :committed_at, presence: true
  validates :realm, inclusion: { in: [REALM] }
  validates :client_id, inclusion: { in: [CLIENT_ID] }
end
