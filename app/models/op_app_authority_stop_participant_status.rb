# typed: false
# frozen_string_literal: true

class OpAppAuthorityStopParticipantStatus < OpBaseAppRecord
  self.record_timestamps = false

  has_many :participants, class_name: "OpAppAuthorityStopParticipant", foreign_key: :status_id, inverse_of: :status,
                          dependent: :restrict_with_exception
end
