# typed: false
# frozen_string_literal: true

class OpComAuthorityStopGrantTarget < OpBaseComRecord
  belongs_to :stop, class_name: "OpComAuthorityStop", inverse_of: :grant_targets
  belongs_to :grant, class_name: "OpComGrant"
end
