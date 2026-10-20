# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_assignments
# Database name: com_zenith
#
#  id                   :bigint           not null, primary key
#  assigned_at          :datetime         not null
#  revoked_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  individual_id        :bigint           not null
#  public_id            :string           not null
#  visitor_identity_id  :bigint           not null
#
# Indexes
#
#  index_individual_assignments_on_individual_id                   (individual_id)
#  index_individual_assignments_on_public_id                       (public_id) UNIQUE
#  index_individual_assignments_on_visitor_identity_id             (visitor_identity_id)
#  idx_individual_assignments_one_active_identity_per_individual   (individual_id,visitor_identity_id) UNIQUE WHERE (revoked_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (individual_id => individuals.id)
#  fk_rails_...  (visitor_identity_id => visitor_identities.id)
#
class IndividualAssignment < ComRpRecord
  include ::AccountAssignment

  belongs_to :individual, inverse_of: :individual_assignments
  belongs_to :visitor_identity, inverse_of: :individual_assignments

  validates :individual_id,
            uniqueness: { scope: :visitor_identity_id, conditions: -> { where(revoked_at: nil) } },
            on: :create, if: -> { revoked_at.nil? }
end
