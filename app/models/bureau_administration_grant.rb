# typed: false
# frozen_string_literal: true

class BureauAdministrationGrant < OrgRpRecord
  belongs_to :bureau, inverse_of: :administration_grants
  belongs_to :operator, inverse_of: :bureau_administration_grants
end
