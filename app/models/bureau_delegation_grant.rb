# typed: false
# frozen_string_literal: true

class BureauDelegationGrant < OrgRpRecord
  belongs_to :bureau, inverse_of: :delegation_grants
  belongs_to :operator, inverse_of: :bureau_delegation_grants
end
