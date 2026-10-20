# frozen_string_literal: true

class RemoveRedundantOpBaseOrgIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:operator_device_sessions, :staff_id, name: "index_operator_device_sessions_on_staff_id", algorithm: :concurrently)
  end
end
