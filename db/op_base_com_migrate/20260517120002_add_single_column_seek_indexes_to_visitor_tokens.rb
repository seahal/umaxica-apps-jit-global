# typed: false
# frozen_string_literal: true

class AddSingleColumnSeekIndexesToVisitorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :visitor_tokens, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :visitor_tokens, :discarded_at, algorithm: :concurrently, if_not_exists: true
    add_index :visitor_tokens, :rotated_at, algorithm: :concurrently, if_not_exists: true
  end
end
