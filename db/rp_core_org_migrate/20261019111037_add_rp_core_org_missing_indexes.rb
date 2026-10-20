# frozen_string_literal: true

class AddRpCoreOrgMissingIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(:rp_refresh_attempts, :session_id, algorithm: :concurrently)
    add_index(:rp_identity_bindings, :principal_id, algorithm: :concurrently)
    add_index(:rp_event_receipts, :op_session_binding_id, algorithm: :concurrently)
    add_index(:rp_op_session_bindings, :identity_binding_id, algorithm: :concurrently)
  end
end
