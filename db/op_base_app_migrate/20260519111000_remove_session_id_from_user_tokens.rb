# typed: false
# frozen_string_literal: true

class RemoveSessionIdFromUserTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :user_tokens, name: "index_user_tokens_on_session_id", algorithm: :concurrently, if_exists: true
    safety_assured { remove_column :user_tokens, :session_id, :string }
  end

  def down
    add_column :user_tokens, :session_id, :string
    add_index :user_tokens, :session_id, algorithm: :concurrently
  end
end
