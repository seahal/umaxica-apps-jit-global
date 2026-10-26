# typed: false
# frozen_string_literal: true

class OpAppAuthorityStopGrantTarget < OpBaseAppRecord
  belongs_to :stop, class_name: "OpAppAuthorityStop", inverse_of: :grant_targets
  belongs_to :grant, class_name: "OpAppGrant"
end
