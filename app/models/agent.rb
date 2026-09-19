# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agents
# Database name: org_zenith
#
#  id                   :bigint           not null, primary key
#  lock_version         :integer          default(0), not null
#  moniker              :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  operator_identity_id :bigint           not null
#  public_id            :string           default(""), not null
#
# Indexes
#
#  idx_agents_one_per_operator_identity  (operator_identity_id) UNIQUE
#  index_agents_on_operator_identity_id  (operator_identity_id)
#  index_agents_on_public_id             (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (operator_identity_id => operator_identities.id) ON DELETE => restrict
#
class Agent < OrgRpRecord
  include ::Persona

  persona_interface_validations

  belongs_to :operator_identity, inverse_of: :agent
  has_many :agent_assignments, dependent: :destroy, inverse_of: :agent
  has_many :agent_memberships, dependent: :destroy, inverse_of: :agent
  has_one :ownership,
          class_name: "AgentOwnership",
          dependent: :restrict_with_error,
          inverse_of: :agent
  has_one :owner, through: :ownership, source: :operator
  has_many :administration_grants,
           class_name: "AgentAdministrationGrant",
           dependent: :restrict_with_error,
           inverse_of: :agent
  has_many :delegation_grants,
           class_name: "AgentDelegationGrant",
           dependent: :restrict_with_error,
           inverse_of: :agent
  has_many :usage_grants,
           class_name: "AgentUsageGrant",
           dependent: :restrict_with_error,
           inverse_of: :agent
  has_many :view_grants,
           class_name: "AgentViewGrant",
           dependent: :restrict_with_error,
           inverse_of: :agent
  has_many :ownership_transfer_requests,
           class_name: "AgentOwnershipTransferRequest",
           dependent: :restrict_with_error,
           inverse_of: :agent
  has_one :avatar_agent_binding, dependent: :destroy, inverse_of: :agent

  validates :operator_identity_id, uniqueness: true
end
