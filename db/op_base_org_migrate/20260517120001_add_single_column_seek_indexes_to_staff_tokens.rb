# typed: false
# frozen_string_literal: true

class AddSingleColumnSeekIndexesToStaffTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :staff_tokens, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :staff_tokens, :discarded_at, algorithm: :concurrently, if_not_exists: true
    add_index :staff_tokens, :rotated_at, algorithm: :concurrently, if_not_exists: true
  end
end
