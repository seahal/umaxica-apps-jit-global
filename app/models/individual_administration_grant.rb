# typed: false
# frozen_string_literal: true

class IndividualAdministrationGrant < ComRpRecord
  belongs_to :individual, inverse_of: :administration_grants
  belongs_to :visitor, inverse_of: :individual_administration_grants
end
