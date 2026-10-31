# typed: false
# frozen_string_literal: true

class DpopProofStateStore
  def self.for(resource_type)
    case resource_type.to_s
    when "operator" then OperatorDpopProofState
    else ClientDpopProofState
    end
  end
end
