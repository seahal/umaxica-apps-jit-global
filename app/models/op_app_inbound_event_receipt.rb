# typed: false
# frozen_string_literal: true

class OpAppInboundEventReceipt < OpBaseAppRecord
  self.table_name = "op_inbound_event_receipts"

  REALM = "app"

  validates :event_id, :issuer, :realm, :client_id, :event_type, :committed_at, presence: true
  validates :realm, inclusion: { in: [REALM] }
end
