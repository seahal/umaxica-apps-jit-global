# typed: false
# frozen_string_literal: true

# One durable Back-Channel Logout outbox row per participating RP grant (D-117, D-121).
class OpComAuthorityStopParticipant < OpBaseComRecord
  include OpAuthorityStopParticipantTransitions

  belongs_to :stop, class_name: "OpComAuthorityStop", inverse_of: :participants
  belongs_to :grant, class_name: "OpComGrant"
  belongs_to :status, class_name: "OpComAuthorityStopParticipantStatus", inverse_of: :participants

  validates :issuer, :client_id, :sid, :endpoint_identity, :next_attempt_at, :deadline_at, :lease_expires_at,
            :last_outcome, presence: true
  validates :delivery_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :client_id, :last_outcome, length: { maximum: 64 }
  validates :issuer, :sid, :endpoint_identity, length: { maximum: 255 }

  public

  def final? = OpAuthorityStopReference::FINAL_PARTICIPANT_STATUS_IDS.include?(status_id)
end
