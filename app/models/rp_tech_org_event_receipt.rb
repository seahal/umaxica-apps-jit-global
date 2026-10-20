# typed: false
# frozen_string_literal: true

class RpTechOrgEventReceipt < RpTechOrgRecord
  self.table_name = "rp_event_receipts"

  CELL = RpCellBinding.fetch("rp_tech_org")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  belongs_to :op_session_binding, class_name: "RpTechOrgOpSessionBinding", inverse_of: :event_receipts

  validates :issuer, :realm, :client_id, :event_type, :jti_digest, :expires_at, :committed_at, presence: true
  validates :jti_digest, uniqueness: { scope: %i(issuer realm client_id event_type) }, on: :create
  validates :realm, inclusion: { in: [REALM] }
  validates :client_id, inclusion: { in: [CLIENT_ID] }
  validates :realm, length: { maximum: 3 }
  validates :client_id, :event_type, length: { maximum: 64 }
  validates :issuer, length: { maximum: 255 }
end
