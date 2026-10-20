# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_memberships
# Database name: org_zenith
#
#  id                   :bigint           not null, primary key
#  ends_at              :datetime
#  metadata             :jsonb            not null
#  primary              :boolean          default(FALSE), not null
#  revoked_at           :datetime
#  starts_at            :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  agent_id             :bigint           not null
#  approved_by_agent_id :bigint
#  bureau_id            :bigint           not null
#  bureau_unit_id       :bigint           not null
#  granted_by_agent_id  :bigint
#  membership_kind_id   :bigint           default(0), not null
#  membership_state_id  :bigint           default(0), not null
#  revoke_reason_id     :bigint
#  revoked_by_agent_id  :bigint
#
# Indexes
#
#  idx_agent_memberships_one_active_primary         (agent_id) UNIQUE WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL))
#  index_agent_memberships_on_agent_id              (agent_id)
#  index_agent_memberships_on_approved_by_agent_id  (approved_by_agent_id)
#  index_agent_memberships_on_bureau_id             (bureau_id)
#  index_agent_memberships_on_bureau_unit_id        (bureau_unit_id)
#  index_agent_memberships_on_granted_by_agent_id   (granted_by_agent_id)
#  index_agent_memberships_on_membership_kind_id    (membership_kind_id)
#  index_agent_memberships_on_membership_state_id   (membership_state_id)
#  index_agent_memberships_on_revoke_reason_id      (revoke_reason_id)
#  index_agent_memberships_on_revoked_by_agent_id   (revoked_by_agent_id)
#
# Foreign Keys
#
#  fk_agent_memberships_unit_same_bureau  ([bureau_unit_id, bureau_id] => bureau_units[id, bureau_id]) ON DELETE => restrict
#  fk_rails_...                           (agent_id => agents.id)
#  fk_rails_...                           (approved_by_agent_id => agents.id) ON DELETE => nullify
#  fk_rails_...                           (bureau_id => bureaus.id)
#  fk_rails_...                           (bureau_unit_id => bureau_units.id)
#  fk_rails_...                           (granted_by_agent_id => agents.id) ON DELETE => nullify
#  fk_rails_...                           (membership_kind_id => agent_membership_kinds.id)
#  fk_rails_...                           (membership_state_id => agent_membership_states.id)
#  fk_rails_...                           (revoke_reason_id => agent_membership_revoke_reasons.id)
#  fk_rails_...                           (revoked_by_agent_id => agents.id) ON DELETE => nullify
#
class AgentMembership < OrgRpRecord
  include ::CollectiveMembership

  collective_membership_config account_foreign_key: :agent_id,
                               collective_foreign_key: :bureau_id,
                               unit_association_name: :bureau_unit

  belongs_to :agent, inverse_of: :agent_memberships
  belongs_to :bureau, inverse_of: :agent_memberships
  belongs_to :bureau_unit, inverse_of: :agent_memberships
  belongs_to :membership_kind,
             class_name: "AgentMembershipKind",
             inverse_of: :agent_memberships
  belongs_to :membership_state,
             class_name: "AgentMembershipState",
             inverse_of: :agent_memberships
  belongs_to :revoke_reason,
             class_name: "AgentMembershipRevokeReason",
             inverse_of: :agent_memberships
  belongs_to :granted_by_agent, class_name: "Agent", inverse_of: false
  belongs_to :approved_by_agent, class_name: "Agent", inverse_of: false
  belongs_to :revoked_by_agent, class_name: "Agent", inverse_of: false

  validates :agent_id,
            uniqueness: {
              conditions: -> { where(primary: true, revoked_at: nil, ends_at: nil) },
            },
            if: :primary?
  validates :agent_id, :bureau_id, :bureau_unit_id, exclusion: { in: [nil] }
end
