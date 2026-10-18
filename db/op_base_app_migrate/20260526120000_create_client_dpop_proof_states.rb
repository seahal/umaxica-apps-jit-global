# typed: false
# frozen_string_literal: true

class CreateClientDpopProofStates < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :client_dpop_proof_states, if_not_exists: true do |t|
      t.string :jti
      t.string :jkt
      t.string :nonce
      t.string :htm
      t.string :htu
      t.datetime :seen_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :nonce_used_at
      t.timestamps
    end

    add_index :client_dpop_proof_states, :jti, unique: true, where: "jti IS NOT NULL",
                                                algorithm: :concurrently, if_not_exists: true
    add_index :client_dpop_proof_states, :nonce, unique: true, where: "nonce IS NOT NULL",
                                                  algorithm: :concurrently, if_not_exists: true
    add_index :client_dpop_proof_states, :expires_at, algorithm: :concurrently, if_not_exists: true
  end
end
