# typed: false
# frozen_string_literal: true

class CompanyViewGrant < ComRpRecord
  belongs_to :company, inverse_of: :view_grants
  belongs_to :visitor, inverse_of: :company_view_grants

  validates :company_id, uniqueness: { scope: :visitor_id }
end
