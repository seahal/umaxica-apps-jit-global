# typed: false
# frozen_string_literal: true

class AddSelectedContextToOperatorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :operator_tokens, :selected_account_public_id, :string
    add_column :operator_tokens, :selected_collective_public_id, :string
    add_column :operator_tokens, :selected_collective_unit_public_id, :string
    add_column :operator_tokens, :selected_at, :datetime

    add_index :operator_tokens, :selected_account_public_id, algorithm: :concurrently
    add_index :operator_tokens, :selected_collective_public_id, algorithm: :concurrently
  end
end
