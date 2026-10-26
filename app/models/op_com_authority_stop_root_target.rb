# typed: false
# frozen_string_literal: true

class OpComAuthorityStopRootTarget < OpBaseComRecord
  belongs_to :stop, class_name: "OpComAuthorityStop", inverse_of: :root_targets
  belongs_to :root, class_name: "VisitorToken"
end
