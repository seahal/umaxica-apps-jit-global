# typed: false
# frozen_string_literal: true

class RpBaseComPrincipal < RpBaseComRecord
  self.table_name = "rp_principals"

  CELL = RpCellBinding.fetch("rp_base_com")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId
  include RpPrincipal

  has_many :identity_bindings, class_name: "RpBaseComIdentityBinding", foreign_key: :principal_id,
                               inverse_of: :principal,
                               dependent: :restrict_with_error
end
