# typed: false
# frozen_string_literal: true

class OpAppAuthorityStopScope < OpBaseAppRecord
  self.record_timestamps = false

  has_many :stops, class_name: "OpAppAuthorityStop", foreign_key: :scope_id, inverse_of: :scope,
                   dependent: :restrict_with_exception
end
