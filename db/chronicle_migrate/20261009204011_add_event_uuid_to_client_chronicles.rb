# frozen_string_literal: true

class AddEventUuidToClientChronicles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:client_chronicles, :event_uuid, :uuid)
    add_index(:client_chronicles, :event_uuid, unique: true, algorithm: :concurrently)
  end
end
