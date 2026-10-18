# typed: false
# frozen_string_literal: true

class CompanyDelegationGrant < ComRpRecord
  belongs_to :company, inverse_of: :delegation_grants
  belongs_to :visitor, inverse_of: :company_delegation_grants
end
