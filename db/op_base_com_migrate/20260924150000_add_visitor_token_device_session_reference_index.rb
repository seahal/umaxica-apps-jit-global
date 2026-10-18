# frozen_string_literal: true

require_relative "../migration_support/device_session_token_indexes"

class AddVisitorTokenDeviceSessionReferenceIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :visitor_tokens
  INDEX = "index_visitor_tokens_on_device_session_id_and_id"
  OLD_INDEX = "index_visitor_tokens_on_device_session_id"

  def up
    DeviceSessionTokenIndexes.up(self, table: TABLE, index_name: INDEX, old_index_name: OLD_INDEX)
  end

  def down
    DeviceSessionTokenIndexes.down(self, table: TABLE, index_name: INDEX, old_index_name: OLD_INDEX)
  end
end
