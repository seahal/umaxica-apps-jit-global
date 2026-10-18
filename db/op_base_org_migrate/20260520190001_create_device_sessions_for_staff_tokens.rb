# typed: false
# frozen_string_literal: true

class CreateDeviceSessionsForStaffTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :operator_device_sessions, if_not_exists: true do |t|
      t.string :public_id, limit: 21, null: false
      t.bigint :staff_id, null: false
      t.string :device_id_digest
      t.string :dbsc_session_id_digest
      t.string :dbsc_public_key_thumbprint
      t.datetime :dbsc_bound_at
      t.string :dpop_jkt
      t.bigint :status_id, default: 1, null: false
      t.bigint :current_refresh_token_id
      t.string :refresh_token_family_id
      t.datetime :last_seen_at
      t.datetime :revoked_at
      t.string :revoke_reason
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :operator_device_sessions, :public_id, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :operator_device_sessions, :staff_id, algorithm: :concurrently, if_not_exists: true
    add_index :operator_device_sessions, :device_id_digest, algorithm: :concurrently, if_not_exists: true
    add_index :operator_device_sessions, :dbsc_session_id_digest, algorithm: :concurrently, if_not_exists: true
    add_index :operator_device_sessions, :current_refresh_token_id, algorithm: :concurrently, if_not_exists: true
    add_index :operator_device_sessions, :refresh_token_family_id, algorithm: :concurrently, if_not_exists: true
    add_index :operator_device_sessions, :revoked_at, algorithm: :concurrently, if_not_exists: true

    add_column :operator_tokens, :device_session_id, :bigint unless column_exists?(:operator_tokens, :device_session_id)
    add_index :operator_tokens, :device_session_id, algorithm: :concurrently, if_not_exists: true
  end
end
