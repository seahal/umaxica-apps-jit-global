# frozen_string_literal: true

class RemoveRedundantOpBaseAppIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:client_device_sessions, :user_id, name: "index_client_device_sessions_on_user_id", algorithm: :concurrently)
  end
end
