# typed: false
# frozen_string_literal: true

class CreateSecurityOneTimeReveals < ActiveRecord::Migration[8.2]
  def change
    create_table :security_one_time_reveals do |t|
      t.string :jti_digest, null: false
      t.string :actor_type, null: false
      t.bigint :actor_id, null: false
      t.string :session_nonce_digest, null: false
      t.string :purpose, null: false
      t.text :encrypted_payload, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :security_one_time_reveals, :jti_digest, unique: true
    add_index :security_one_time_reveals, :expires_at
  end
end
