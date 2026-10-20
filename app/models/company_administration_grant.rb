# typed: false
# frozen_string_literal: true

class CompanyAdministrationGrant < ComRpRecord
  belongs_to :company, inverse_of: :administration_grants
  belongs_to :visitor, inverse_of: :company_administration_grants

  validates :company_id, uniqueness: { scope: :visitor_id }
end
