# typed: false
# frozen_string_literal: true

class AddOidcRefreshClaimsToOperatorRpSessions < ActiveRecord::Migration[8.2]
  def change
    add_column(:operator_rp_sessions, :oidc_auth_time, :datetime)
    add_column(:operator_rp_sessions, :oidc_acr, :string)
    add_column(:operator_rp_sessions, :oidc_amr, :text)
    add_column(:operator_rp_sessions, :oidc_nonce, :string)
  end
end
