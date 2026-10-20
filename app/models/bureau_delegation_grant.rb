# typed: false
# frozen_string_literal: true

class BureauDelegationGrant < OrgRpRecord
  belongs_to :bureau, inverse_of: :delegation_grants
  belongs_to :operator, inverse_of: :bureau_delegation_grants

  validates :bureau_id, uniqueness: { scope: :operator_id }
end
