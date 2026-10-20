# typed: false
# frozen_string_literal: true

class OpOrgOutboxEvent < OpBaseOrgRecord
  self.table_name = "op_outbox_events"

  REALM = "org"

  belongs_to :logout_flow_participant, class_name: "OpOrgLogoutFlowParticipant",
                                       inverse_of: :outbox_events, optional: true

  validates :event_id, :event_type, :target_realm, :target_client_id, :target_endpoint_identity,
            :stable_event_ref, :delivery_attempts, :next_attempt_at, presence: true
  validates :target_realm, inclusion: { in: [REALM] }
  validates :delivery_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :target_realm, length: { maximum: 3 }
  validates :event_type, :last_error_code, :target_client_id, length: { maximum: 64 }
  validates :stable_event_ref, length: { maximum: 128 }
  validates :target_endpoint_identity, length: { maximum: 255 }
end
