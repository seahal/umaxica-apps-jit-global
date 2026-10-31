# typed: false
# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def show?
    organization_has_current_principal_membership?
  end

  private

  def organization_has_current_principal_membership?
    case record
    when Enterprise
      return false unless user.is_a?(Client)

      record.persona_memberships.active.joins(persona: :client_identity)
        .exists?(client_identities: { source_record_id: user.id })
    when Bureau
      return false unless user.is_a?(Operator)

      record.agent_memberships.active.joins(agent: :operator_identity)
        .exists?(operator_identities: { source_record_id: user.id })
    else
      false
    end
  end
end
