# typed: false
# frozen_string_literal: true

class AgentUsageGrant < OrgRpRecord
  belongs_to :agent, inverse_of: :usage_grants
  belongs_to :operator, inverse_of: :agent_usage_grants
end
