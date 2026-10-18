# typed: false
# frozen_string_literal: true

class CreateAcmeLogoutTransactions < ActiveRecord::Migration[8.2]
  def change
    create_table :acme_logout_transactions do |t|
      t.string :public_id, null: false
      t.string :origin_surface, null: false
      t.string :initiating_client_id, null: false
      t.text :completion_url, null: false
      t.string :actor_ref
      t.string :session_ref
      t.string :callback_state
      t.string :status, null: false, default: "initiated"
      t.string :expected_step, null: false, default: "origin_cleared"
      t.jsonb :completed_steps, null: false, default: []
      t.datetime :expires_at, null: false
      t.datetime :finalized_at
      t.datetime :failed_at

      t.timestamps
    end

    add_index :acme_logout_transactions, :public_id, unique: true
    add_index :acme_logout_transactions, :origin_surface
    add_index :acme_logout_transactions, :status
    add_index :acme_logout_transactions, :expires_at
  end
end
