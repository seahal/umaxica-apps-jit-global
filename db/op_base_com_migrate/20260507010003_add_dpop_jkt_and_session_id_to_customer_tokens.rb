# typed: false
# frozen_string_literal: true

class AddDpopJktAndSessionIdToCustomerTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :customer_tokens, :dpop_jkt, :string
    add_column :customer_tokens, :session_id, :string
    add_index :customer_tokens, :session_id, algorithm: :concurrently
  end
end
