# typed: false
# frozen_string_literal: true

class OpAppAuthorityStopRootTarget < OpBaseAppRecord
  belongs_to :stop, class_name: "OpAppAuthorityStop", inverse_of: :root_targets
  belongs_to :root, class_name: "ClientToken"
end
