# frozen_string_literal: true
class AddCleanupStateToClientSignUpCycles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_column :client_sign_up_cycles, :cleanup_status, :string, null: false, default: "idle" unless
      column_exists?(:client_sign_up_cycles, :cleanup_status)
    add_column :client_sign_up_cycles, :cleanup_attempted_at, :datetime unless
      column_exists?(:client_sign_up_cycles, :cleanup_attempted_at)
    add_column :client_sign_up_cycles, :cleanup_completed_at, :datetime unless
      column_exists?(:client_sign_up_cycles, :cleanup_completed_at)
    add_column :client_sign_up_cycles, :cleanup_error_code, :string unless
      column_exists?(:client_sign_up_cycles, :cleanup_error_code)
    add_column :client_sign_up_cycles, :pending_passkey_registration_id, :bigint unless
      column_exists?(:client_sign_up_cycles, :pending_passkey_registration_id)

    add_index :client_sign_up_cycles, [:cleanup_status, :purged_at],
              name: "index_client_sign_up_cycles_on_cleanup_status_and_purged_at",
              algorithm: :concurrently,
              if_not_exists: true
    add_index :client_sign_up_cycles, :pending_passkey_registration_id,
              name: "index_client_sign_up_cycles_on_pending_passkey_registration_id",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :client_sign_up_cycles,
                 name: "index_client_sign_up_cycles_on_pending_passkey_registration_id",
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :client_sign_up_cycles,
                 name: "index_client_sign_up_cycles_on_cleanup_status_and_purged_at",
                 algorithm: :concurrently,
                 if_exists: true

    remove_column :client_sign_up_cycles, :pending_passkey_registration_id if
      column_exists?(:client_sign_up_cycles, :pending_passkey_registration_id)
    remove_column :client_sign_up_cycles, :cleanup_error_code if
      column_exists?(:client_sign_up_cycles, :cleanup_error_code)
    remove_column :client_sign_up_cycles, :cleanup_completed_at if
      column_exists?(:client_sign_up_cycles, :cleanup_completed_at)
    remove_column :client_sign_up_cycles, :cleanup_attempted_at if
      column_exists?(:client_sign_up_cycles, :cleanup_attempted_at)
    remove_column :client_sign_up_cycles, :cleanup_status if
      column_exists?(:client_sign_up_cycles, :cleanup_status)
  end
end
