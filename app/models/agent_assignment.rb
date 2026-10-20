# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_assignments
# Database name: org_zenith
#
#  id                   :bigint           not null, primary key
#  assigned_at          :datetime         not null
#  revoked_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  agent_id             :bigint           not null
#  operator_identity_id  :bigint           not null
#  public_id            :string           not null
#
# Indexes
#
#  index_agent_assignments_on_agent_id                            (agent_id)
#  index_agent_assignments_on_operator_identity_id                (operator_identity_id)
#  index_agent_assignments_on_public_id                           (public_id) UNIQUE
#  idx_agent_assignments_one_active_identity_per_agent           (agent_id,operator_identity_id) UNIQUE WHERE (revoked_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (operator_identity_id => operator_identities.id)
#
class AgentAssignment < OrgRpRecord
  include ::AccountAssignment

  belongs_to :agent, inverse_of: :agent_assignments
  belongs_to :operator_identity, inverse_of: :agent_assignments

  validates :agent_id,
            uniqueness: { scope: :operator_identity_id, conditions: -> { where(revoked_at: nil) } },
            on: :create, if: -> { revoked_at.nil? }
end
