# typed: false
# frozen_string_literal: true

class OpAppLogoutFlowParticipant < OpBaseAppRecord
  self.table_name = "logout_flow_participants"

  REALM = "app"

  belongs_to :logout_flow, class_name: "OpAppLogoutFlow", inverse_of: :participants
  has_many :outbox_events, class_name: "OpAppOutboxEvent", foreign_key: :logout_flow_participant_id,
                           inverse_of: :logout_flow_participant,
                           dependent: :restrict_with_exception

  validates :issuer, :realm, :client_id, :sid, :endpoint_identity, presence: true
  validates :realm, inclusion: { in: [REALM] }
  validates :delivery_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                                presence: true
end
