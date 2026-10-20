# typed: false
# frozen_string_literal: true

class OpComInboundEventReceipt < OpBaseComRecord
  self.table_name = "op_inbound_event_receipts"

  REALM = "com"

  validates :event_id, :issuer, :realm, :client_id, :event_type, :committed_at, presence: true
  validates :event_id, uniqueness: { scope: %i(issuer realm client_id) }, on: :create
  validates :realm, inclusion: { in: [REALM] }
  validates :realm, length: { maximum: 3 }
  validates :client_id, :event_type, length: { maximum: 64 }
  validates :issuer, length: { maximum: 255 }
end
