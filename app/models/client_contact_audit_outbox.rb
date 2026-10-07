# frozen_string_literal: true

class ClientContactAuditOutbox < AppZenithRecord
  include ContactAuditOutbox

  attr_readonly :event_uuid, :contact_kind, :event_name, :owner_ref, :contact_ref,
                :operation_ref, :actor_ref, :occurred_at

  validates :event_uuid, :owner_ref, :contact_ref, :operation_ref, :occurred_at, presence: true
  validates :contact_kind, inclusion: { in: %w(email telephone) }
  validates :event_name, inclusion: { in: %w(finalized released) }
end
