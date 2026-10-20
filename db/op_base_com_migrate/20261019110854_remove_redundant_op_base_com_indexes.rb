# frozen_string_literal: true

class RemoveRedundantOpBaseComIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:visitor_device_sessions, :visitor_id, name: "index_visitor_device_sessions_on_visitor_id", algorithm: :concurrently)
  end
end
