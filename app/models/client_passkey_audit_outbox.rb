# typed: false
# frozen_string_literal: true

class ClientPasskeyAuditOutbox < AppZenithRecord
  include PasskeyAuditOutbox

  attr_readonly :event_uuid, :event_type, :surface, :external_id, :actor_ref, :operation_ref,
                :metadata, :occurred_at

  validates :event_uuid, :event_type, :surface, :external_id, :occurred_at, presence: true
  validates :event_type, inclusion: { in: PasskeyAuditOutbox::EVENT_TYPES }
  validates :surface, inclusion: { in: ["app"] }
end
