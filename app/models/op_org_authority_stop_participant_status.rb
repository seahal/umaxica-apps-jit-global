# typed: false
# frozen_string_literal: true

class OpOrgAuthorityStopParticipantStatus < OpBaseOrgRecord
  self.record_timestamps = false

  has_many :participants, class_name: "OpOrgAuthorityStopParticipant", foreign_key: :status_id, inverse_of: :status,
                          dependent: :restrict_with_exception
end
