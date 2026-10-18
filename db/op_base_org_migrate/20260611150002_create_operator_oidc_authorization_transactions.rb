# typed: false
# frozen_string_literal: true

class CreateOperatorOidcAuthorizationTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :operator_oidc_authorization_transactions do |t|
      t.string :transaction_id, null: false
      t.string :surface, null: false
      t.string :intent, null: false
      t.string :client_id, null: false
      t.string :redirect_uri, null: false
      t.string :response_type, null: false
      t.string :scope, null: false
      t.string :state, null: false
      t.string :nonce, null: false
      t.string :code_challenge, null: false
      t.string :code_challenge_method, null: false
      t.string :login_challenge, null: false
      t.datetime :login_challenge_expires_at, null: false
      t.datetime :authenticated_at
      t.string :actor_ref
      t.string :session_ref
      t.string :auth_method
      t.string :acr
      t.datetime :consumed_at
      t.datetime :expires_at, null: false
      t.string :status, null: false

      t.timestamps
    end

    add_index :operator_oidc_authorization_transactions, :transaction_id, unique: true
    add_index :operator_oidc_authorization_transactions, :login_challenge, unique: true
    add_index :operator_oidc_authorization_transactions, %i[client_id login_challenge]
  end
end
