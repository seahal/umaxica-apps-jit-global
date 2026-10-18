# frozen_string_literal: true

require_relative "../migration_support/device_session_root_and_rp_binding"

class HardenComTicketBrowserSessionBindings < ActiveRecord::Migration[8.2]
  def up
    DeviceSessionRootAndRpBinding.up(
      self,
      token_table: :visitor_tokens,
      device_table: :visitor_device_sessions,
      rp_table: :visitor_rp_sessions,
      actor_column: :visitor_id,
      token_parent_column: :visitor_token_id,
      old_active_index: "idx_active_visitor_rp_session_per_rp",
      new_active_index: "idx_active_visitor_rp_session_per_device_session",
      rp_device_foreign_key: "fk_visitor_rp_sessions_on_device_session_id",
    )
  end

  def down
    DeviceSessionRootAndRpBinding.down(self)
  end
end
