# typed: false
# frozen_string_literal: true

class OpComAuthorityStopCause < OpBaseComRecord
  self.record_timestamps = false

  has_many :stops, class_name: "OpComAuthorityStop", foreign_key: :cause_id, inverse_of: :cause,
                   dependent: :restrict_with_exception
end
