# typed: false
# frozen_string_literal: true

class RemoveDeviceIdFromComTickets < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :visitor_tokens, :device_id, if_exists: true, algorithm: :concurrently
    remove_index :visitor_tokens, :device_id_digest, if_exists: true, algorithm: :concurrently
    remove_index :visitor_device_sessions, :device_id_digest, if_exists: true, algorithm: :concurrently

    safety_assured { remove_column :visitor_tokens, :device_id, :string } if column_exists?(:visitor_tokens, :device_id)
    safety_assured { remove_column :visitor_tokens, :device_id_digest, :string } if column_exists?(:visitor_tokens, :device_id_digest)
    if column_exists?(:visitor_device_sessions, :device_id_digest)
      safety_assured { remove_column :visitor_device_sessions, :device_id_digest, :string }
    end
  end

  def down
    add_column :visitor_tokens, :device_id, :string, default: "", null: false unless column_exists?(:visitor_tokens, :device_id)
    add_column :visitor_tokens, :device_id_digest, :string unless column_exists?(:visitor_tokens, :device_id_digest)
    unless column_exists?(:visitor_device_sessions, :device_id_digest)
      add_column :visitor_device_sessions, :device_id_digest, :string
    end

    add_index :visitor_tokens, :device_id, algorithm: :concurrently, if_not_exists: true
    add_index :visitor_tokens, :device_id_digest, algorithm: :concurrently, if_not_exists: true
    add_index :visitor_device_sessions, :device_id_digest, algorithm: :concurrently, if_not_exists: true
  end
end
