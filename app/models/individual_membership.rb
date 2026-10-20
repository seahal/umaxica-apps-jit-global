# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_memberships
# Database name: com_zenith
#
#  id                        :bigint           not null, primary key
#  ends_at                   :datetime
#  metadata                  :jsonb            not null
#  primary                   :boolean          default(FALSE), not null
#  revoked_at                :datetime
#  starts_at                 :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  approved_by_individual_id :bigint
#  company_id                :bigint           not null
#  company_unit_id           :bigint           not null
#  granted_by_individual_id  :bigint
#  individual_id             :bigint           not null
#  membership_kind_id        :bigint           default(0), not null
#  membership_state_id       :bigint           default(0), not null
#  revoke_reason_id          :bigint
#  revoked_by_individual_id  :bigint
#
# Indexes
#
#  idx_individual_memberships_one_active_primary              (individual_id) UNIQUE WHERE (("primary" = true) AND (revoked_at IS NULL) AND (ends_at IS NULL))
#  index_individual_memberships_on_approved_by_individual_id  (approved_by_individual_id)
#  index_individual_memberships_on_company_id                 (company_id)
#  index_individual_memberships_on_company_unit_id            (company_unit_id)
#  index_individual_memberships_on_granted_by_individual_id   (granted_by_individual_id)
#  index_individual_memberships_on_individual_id              (individual_id)
#  index_individual_memberships_on_membership_kind_id         (membership_kind_id)
#  index_individual_memberships_on_membership_state_id        (membership_state_id)
#  index_individual_memberships_on_revoke_reason_id           (revoke_reason_id)
#  index_individual_memberships_on_revoked_by_individual_id   (revoked_by_individual_id)
#
# Foreign Keys
#
#  fk_individual_memberships_unit_same_company  ([company_unit_id, company_id] => company_units[id, company_id]) ON DELETE => restrict
#  fk_rails_...                                 (approved_by_individual_id => individuals.id) ON DELETE => nullify
#  fk_rails_...                                 (company_id => companies.id)
#  fk_rails_...                                 (company_unit_id => company_units.id)
#  fk_rails_...                                 (granted_by_individual_id => individuals.id) ON DELETE => nullify
#  fk_rails_...                                 (individual_id => individuals.id)
#  fk_rails_...                                 (membership_kind_id => individual_membership_kinds.id)
#  fk_rails_...                                 (membership_state_id => individual_membership_states.id)
#  fk_rails_...                                 (revoke_reason_id => individual_membership_revoke_reasons.id)
#  fk_rails_...                                 (revoked_by_individual_id => individuals.id) ON DELETE => nullify
#
class IndividualMembership < ComRpRecord
  include ::CollectiveMembership

  collective_membership_config account_foreign_key: :individual_id,
                               collective_foreign_key: :company_id,
                               unit_association_name: :company_unit

  belongs_to :individual, inverse_of: :individual_memberships
  belongs_to :company, inverse_of: :individual_memberships
  belongs_to :company_unit, inverse_of: :individual_memberships
  belongs_to :membership_kind,
             class_name: "IndividualMembershipKind",
             inverse_of: :individual_memberships
  belongs_to :membership_state,
             class_name: "IndividualMembershipState",
             inverse_of: :individual_memberships
  belongs_to :revoke_reason,
             class_name: "IndividualMembershipRevokeReason",
             inverse_of: :individual_memberships
  belongs_to :granted_by_individual, class_name: "Individual", inverse_of: false
  belongs_to :approved_by_individual, class_name: "Individual", inverse_of: false
  belongs_to :revoked_by_individual, class_name: "Individual", inverse_of: false

  validates :individual_id,
            uniqueness: {
              conditions: -> { where(primary: true, revoked_at: nil, ends_at: nil) },
            },
            if: :primary?
  validates :company_id, :company_unit_id, :individual_id, exclusion: { in: [nil] }
end
