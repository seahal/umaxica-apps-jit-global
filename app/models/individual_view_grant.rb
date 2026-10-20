# typed: false
# frozen_string_literal: true

class IndividualViewGrant < ComRpRecord
  belongs_to :individual, inverse_of: :view_grants
  belongs_to :visitor, inverse_of: :individual_view_grants

  validates :individual_id, uniqueness: { scope: :visitor_id }
end
