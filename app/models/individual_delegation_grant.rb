# typed: false
# frozen_string_literal: true

class IndividualDelegationGrant < ComRpRecord
  belongs_to :individual, inverse_of: :delegation_grants
  belongs_to :visitor, inverse_of: :individual_delegation_grants

  validates :individual_id, uniqueness: { scope: :visitor_id }
end
