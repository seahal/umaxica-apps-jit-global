# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_memberships
# Database name: app_zenith
#
#  id                     :bigint           not null, primary key
#  ends_at                :datetime
#  metadata               :jsonb            not null
#  primary                :boolean          default(FALSE), not null
#  revoked_at             :datetime
#  starts_at              :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  approved_by_persona_id :bigint
#  enterprise_id          :bigint           not null
#  enterprise_unit_id     :bigint           not null
#  granted_by_persona_id  :bigint
#  membership_kind_id     :bigint           default(0), not null
#  membership_state_id    :bigint           default(0), not null
#  persona_id             :bigint           not null
#  revoke_reason_id       :bigint
#  revoked_by_persona_id  :bigint
#
# Indexes
#
#  idx_persona_memberships_one_active_primary           (persona_id) UNIQUE WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL))
#  index_persona_memberships_on_approved_by_persona_id  (approved_by_persona_id)
#  index_persona_memberships_on_enterprise_id           (enterprise_id)
#  index_persona_memberships_on_enterprise_unit_id      (enterprise_unit_id)
#  index_persona_memberships_on_granted_by_persona_id   (granted_by_persona_id)
#  index_persona_memberships_on_membership_kind_id      (membership_kind_id)
#  index_persona_memberships_on_membership_state_id     (membership_state_id)
#  index_persona_memberships_on_persona_id              (persona_id)
#  index_persona_memberships_on_revoke_reason_id        (revoke_reason_id)
#  index_persona_memberships_on_revoked_by_persona_id   (revoked_by_persona_id)
#
# Foreign Keys
#
#  fk_persona_memberships_unit_same_enterprise  ([enterprise_unit_id, enterprise_id] => enterprise_units[id, enterprise_id]) ON DELETE => restrict
#  fk_rails_...                                 (approved_by_persona_id => personas.id) ON DELETE => nullify
#  fk_rails_...                                 (enterprise_id => enterprises.id)
#  fk_rails_...                                 (enterprise_unit_id => enterprise_units.id)
#  fk_rails_...                                 (granted_by_persona_id => personas.id) ON DELETE => nullify
#  fk_rails_...                                 (membership_kind_id => persona_membership_kinds.id)
#  fk_rails_...                                 (membership_state_id => persona_membership_states.id)
#  fk_rails_...                                 (persona_id => personas.id)
#  fk_rails_...                                 (revoke_reason_id => persona_membership_revoke_reasons.id)
#  fk_rails_...                                 (revoked_by_persona_id => personas.id) ON DELETE => nullify
#
class PersonaMembership < AppRpRecord
  include ::CollectiveMembership

  collective_membership_config account_foreign_key: :persona_id,
                               collective_foreign_key: :enterprise_id,
                               unit_association_name: :enterprise_unit

  belongs_to :persona, class_name: "ClientPersona", inverse_of: :persona_memberships
  belongs_to :enterprise, inverse_of: :persona_memberships
  belongs_to :enterprise_unit, inverse_of: :persona_memberships
  belongs_to :membership_kind,
             class_name: "PersonaMembershipKind",
             inverse_of: :persona_memberships
  belongs_to :membership_state,
             class_name: "PersonaMembershipState",
             inverse_of: :persona_memberships
  belongs_to :revoke_reason,
             class_name: "PersonaMembershipRevokeReason",
             inverse_of: :persona_memberships
  belongs_to :granted_by_persona, class_name: "ClientPersona", inverse_of: false
  belongs_to :approved_by_persona, class_name: "ClientPersona", inverse_of: false
  belongs_to :revoked_by_persona, class_name: "ClientPersona", inverse_of: false

  validates :persona_id,
            uniqueness: {
              conditions: -> { where(primary: true, revoked_at: nil, ends_at: nil) },
            },
            if: :primary?
end
