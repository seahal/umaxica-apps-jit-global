# typed: false
# frozen_string_literal: true

class OpOrgInboundEventReceipt < OpBaseOrgRecord
  self.table_name = "op_inbound_event_receipts"

  REALM = "org"

  validates :event_id, :issuer, :realm, :client_id, :event_type, :committed_at, presence: true
  validates :realm, inclusion: { in: [REALM] }
end
