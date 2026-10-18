# typed: false
# frozen_string_literal: true

class RpTechOrgPrincipal < RpTechOrgRecord
  self.table_name = "rp_principals"

  CELL = RpCellBinding.fetch("rp_tech_org")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId
  include RpPrincipal

  has_many :identity_bindings, class_name: "RpTechOrgIdentityBinding", foreign_key: :principal_id,
                               inverse_of: :principal,
                               dependent: :restrict_with_error
end
