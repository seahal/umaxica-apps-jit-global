# frozen_string_literal: true

require_relative "../migration_support/device_session_token_indexes"

class AddOperatorDeviceSessionActorReferenceIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    DeviceSessionTokenIndexes.ensure_actor_reference_index!(
      self, table: :operator_device_sessions, index_name: "index_operator_device_sessions_on_staff_id_and_id", actor_column: :staff_id,
    )
  end

  def down
    DeviceSessionTokenIndexes.remove_actor_reference_index!(
      self, table: :operator_device_sessions, index_name: "index_operator_device_sessions_on_staff_id_and_id", actor_column: :staff_id,
    )
  end
end
