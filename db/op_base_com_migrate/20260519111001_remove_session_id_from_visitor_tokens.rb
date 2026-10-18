# typed: false
# frozen_string_literal: true

class RemoveSessionIdFromVisitorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :visitor_tokens, name: "index_visitor_tokens_on_session_id", algorithm: :concurrently, if_exists: true
    safety_assured { remove_column :visitor_tokens, :session_id, :string }
  end

  def down
    add_column :visitor_tokens, :session_id, :string
    add_index :visitor_tokens, :session_id, algorithm: :concurrently
  end
end
