# typed: false
# frozen_string_literal: true

class RpWarpAppPrincipal < RpWarpAppRecord
  self.table_name = "rp_principals"

  CELL = RpCellBinding.fetch("rp_warp_app")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId
  include RpPrincipal

  has_many :identity_bindings, class_name: "RpWarpAppIdentityBinding", foreign_key: :principal_id,
                               inverse_of: :principal,
                               dependent: :restrict_with_error
end
