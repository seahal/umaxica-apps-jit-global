# typed: false
# frozen_string_literal: true

class OpAppAuthorityStopCause < OpBaseAppRecord
  self.record_timestamps = false

  has_many :stops, class_name: "OpAppAuthorityStop", foreign_key: :cause_id, inverse_of: :cause,
                   dependent: :restrict_with_exception
end
