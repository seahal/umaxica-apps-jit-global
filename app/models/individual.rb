# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individuals
# Database name: com_zenith
#
#  id                  :bigint           not null, primary key
#  lock_version        :integer          default(0), not null
#  moniker             :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  public_id           :string           default(""), not null
#  visitor_identity_id :bigint           not null
#
# Indexes
#
#  idx_individuals_one_per_visitor_identity  (visitor_identity_id) UNIQUE
#  index_individuals_on_public_id            (public_id) UNIQUE
#  index_individuals_on_visitor_identity_id  (visitor_identity_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_identity_id => visitor_identities.id) ON DELETE => restrict
#
class Individual < ComRpRecord
  include ::Persona

  persona_interface_validations

  belongs_to :visitor_identity, inverse_of: :individual
  has_many :individual_assignments, dependent: :destroy, inverse_of: :individual
  has_many :individual_memberships, dependent: :destroy, inverse_of: :individual
  has_one :ownership,
          class_name: "IndividualOwnership",
          dependent: :restrict_with_error,
          inverse_of: :individual
  has_one :owner, through: :ownership, source: :visitor
  has_many :administration_grants,
           class_name: "IndividualAdministrationGrant",
           dependent: :restrict_with_error,
           inverse_of: :individual
  has_many :delegation_grants,
           class_name: "IndividualDelegationGrant",
           dependent: :restrict_with_error,
           inverse_of: :individual
  has_many :usage_grants,
           class_name: "IndividualUsageGrant",
           dependent: :restrict_with_error,
           inverse_of: :individual
  has_many :view_grants,
           class_name: "IndividualViewGrant",
           dependent: :restrict_with_error,
           inverse_of: :individual
  has_many :ownership_transfer_requests,
           class_name: "IndividualOwnershipTransferRequest",
           dependent: :restrict_with_error,
           inverse_of: :individual
  has_one :avatar_individual_binding, dependent: :destroy, inverse_of: :individual

  validates :visitor_identity_id, uniqueness: true
end
