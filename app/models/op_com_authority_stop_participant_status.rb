# typed: false
# frozen_string_literal: true

class OpComAuthorityStopParticipantStatus < OpBaseComRecord
  self.record_timestamps = false

  has_many :participants, class_name: "OpComAuthorityStopParticipant", foreign_key: :status_id, inverse_of: :status,
                          dependent: :restrict_with_exception
end
