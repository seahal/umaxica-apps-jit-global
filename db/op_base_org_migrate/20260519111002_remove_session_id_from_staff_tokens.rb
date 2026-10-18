# typed: false
# frozen_string_literal: true

class RemoveSessionIdFromStaffTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :staff_tokens, name: "index_staff_tokens_on_session_id", algorithm: :concurrently, if_exists: true
    safety_assured { remove_column :staff_tokens, :session_id, :string }
  end

  def down
    add_column :staff_tokens, :session_id, :string
    add_index :staff_tokens, :session_id, algorithm: :concurrently
  end
end
