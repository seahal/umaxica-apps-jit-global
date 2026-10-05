# frozen_string_literal: true

class ValidateClientOidcSecretSignInFlowForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(
      :client_oidc_authorization_transactions, :client_sign_in_flows,
      column: :secret_sign_in_flow_id,
    )
  end
end
