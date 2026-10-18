# typed: false
# frozen_string_literal: true

class RpCoreAppCallbackState < RpCoreAppRecord
  self.table_name = "rp_callback_states"

  CELL = RpCellBinding.fetch("rp_core_app")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  validates :state_digest, :browser_binding_digest, :nonce_digest, :pkce_challenge,
            :pkce_verifier_ciphertext, :issuer, :realm, :client_id, :expires_at, presence: true
  validates :realm, inclusion: { in: [REALM] }
  validates :client_id, inclusion: { in: [CLIENT_ID] }

  public

  def consumed?
    consumed_at.present?
  end
end
