# typed: false
# frozen_string_literal: true

class AgentAdministrationGrant < OrgRpRecord
  belongs_to :agent, inverse_of: :administration_grants
  belongs_to :operator, inverse_of: :agent_administration_grants
end
