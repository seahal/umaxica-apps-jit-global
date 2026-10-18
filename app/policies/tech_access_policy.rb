# typed: false
# frozen_string_literal: true

class TechAccessPolicy < ApplicationPolicy
  public

  def show?
    return false unless record.is_a?(Operator)

    OrgZenithRecord.connected_to(role: :writing) do
      Operator.find_by(id: record.id)&.capability?(OperatorCapabilityGrant::TECH_ACCESS) || false
    end
  end
end
