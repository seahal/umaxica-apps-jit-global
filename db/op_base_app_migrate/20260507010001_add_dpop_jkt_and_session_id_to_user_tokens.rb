# typed: false
# frozen_string_literal: true

class AddDpopJktAndSessionIdToUserTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :user_tokens, :dpop_jkt, :string
    add_column :user_tokens, :session_id, :string
    add_index :user_tokens, :session_id, algorithm: :concurrently
  end
end
