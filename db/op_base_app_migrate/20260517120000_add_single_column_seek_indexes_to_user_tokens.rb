# typed: false
# frozen_string_literal: true

class AddSingleColumnSeekIndexesToUserTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :user_tokens, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :user_tokens, :discarded_at, algorithm: :concurrently, if_not_exists: true
    add_index :user_tokens, :rotated_at, algorithm: :concurrently, if_not_exists: true
  end
end
