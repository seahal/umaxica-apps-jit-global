# typed: false
# frozen_string_literal: true

class AddDpopJktAndSessionIdToStaffTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :staff_tokens, :dpop_jkt, :string
    add_column :staff_tokens, :session_id, :string
    add_index :staff_tokens, :session_id, algorithm: :concurrently
  end
end
