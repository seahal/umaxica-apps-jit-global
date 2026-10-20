# typed: false
# frozen_string_literal: true

class BureauViewGrant < OrgRpRecord
  belongs_to :bureau, inverse_of: :view_grants
  belongs_to :operator, inverse_of: :bureau_view_grants

  validates :bureau_id, uniqueness: { scope: :operator_id }
end
