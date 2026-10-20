# typed: false
# frozen_string_literal: true

class IndividualUsageGrant < ComRpRecord
  belongs_to :individual, inverse_of: :usage_grants
  belongs_to :visitor, inverse_of: :individual_usage_grants

  validates :individual_id, uniqueness: { scope: :visitor_id }
end
