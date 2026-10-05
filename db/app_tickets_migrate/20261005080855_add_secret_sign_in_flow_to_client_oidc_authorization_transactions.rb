# frozen_string_literal: true

class AddSecretSignInFlowToClientOidcAuthorizationTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :client_oidc_authorization_transactions, :secret_sign_in_flow,
      null: true, index: { unique: true, algorithm: :concurrently },
    )
    add_foreign_key(
      :client_oidc_authorization_transactions, :client_sign_in_flows,
      column: :secret_sign_in_flow_id, on_delete: :restrict, validate: false,
    )
  end
end
