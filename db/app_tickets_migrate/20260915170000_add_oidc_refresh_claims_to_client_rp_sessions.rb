# typed: false
# frozen_string_literal: true

class AddOidcRefreshClaimsToClientRpSessions < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_rp_sessions, :oidc_auth_time, :datetime)
    add_column(:client_rp_sessions, :oidc_acr, :string)
    add_column(:client_rp_sessions, :oidc_amr, :text)
    add_column(:client_rp_sessions, :oidc_nonce, :string)
  end
end
