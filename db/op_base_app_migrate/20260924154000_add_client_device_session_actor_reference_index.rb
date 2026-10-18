# frozen_string_literal: true

require_relative "../migration_support/device_session_token_indexes"

class AddClientDeviceSessionActorReferenceIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    DeviceSessionTokenIndexes.ensure_actor_reference_index!(
      self, table: :client_device_sessions, index_name: "index_client_device_sessions_on_user_id_and_id", actor_column: :user_id,
    )
  end

  def down
    DeviceSessionTokenIndexes.remove_actor_reference_index!(
      self, table: :client_device_sessions, index_name: "index_client_device_sessions_on_user_id_and_id", actor_column: :user_id,
    )
  end
end
