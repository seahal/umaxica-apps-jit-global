# typed: false
# frozen_string_literal: true

class AgentDelegationGrant < OrgRpRecord
  belongs_to :agent, inverse_of: :delegation_grants
  belongs_to :operator, inverse_of: :agent_delegation_grants
end
