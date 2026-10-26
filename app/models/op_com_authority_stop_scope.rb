# typed: false
# frozen_string_literal: true

class OpComAuthorityStopScope < OpBaseComRecord
  self.record_timestamps = false

  has_many :stops, class_name: "OpComAuthorityStop", foreign_key: :scope_id, inverse_of: :scope,
                   dependent: :restrict_with_exception
end
