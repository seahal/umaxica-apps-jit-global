# typed: false
# frozen_string_literal: true

class CreateClientSessionLimitResolutionTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :client_session_limit_resolution_transactions do |t|
      t.string :challenge_digest, null: false
      t.string :actor_type, null: false
      t.string :actor_ref, null: false
      t.bigint :oidc_authorization_transaction_id, null: false
      t.string :status, null: false
      t.string :selected_session_ref
      t.datetime :expires_at, null: false
      t.datetime :selected_at
      t.datetime :resolved_at
      t.datetime :cancelled_at
      t.datetime :consumed_at
      t.datetime :finalized_at
      t.jsonb :audit_context, null: false, default: {}

      t.timestamps
    end

    add_index :client_session_limit_resolution_transactions, :challenge_digest, unique: true
    add_index :client_session_limit_resolution_transactions,
              :oidc_authorization_transaction_id,
              name: "idx_client_session_limit_resolution_on_oidc_tx"
    add_index :client_session_limit_resolution_transactions, %i[actor_type actor_ref status],
              name: "idx_client_session_limit_resolution_on_actor_status"
    add_index :client_session_limit_resolution_transactions, :expires_at
  end
end
