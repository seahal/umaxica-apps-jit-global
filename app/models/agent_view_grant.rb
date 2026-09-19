# typed: false
# frozen_string_literal: true

class AgentViewGrant < OrgRpRecord
  belongs_to :agent, inverse_of: :view_grants
  belongs_to :operator, inverse_of: :agent_view_grants
end
