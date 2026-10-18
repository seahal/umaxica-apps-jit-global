# typed: false
# frozen_string_literal: true

class AddSelectedContextToClientTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :client_tokens, :selected_account_public_id, :string
    add_column :client_tokens, :selected_collective_public_id, :string
    add_column :client_tokens, :selected_collective_unit_public_id, :string
    add_column :client_tokens, :selected_avatar_public_id, :string
    add_column :client_tokens, :selected_at, :datetime

    add_index :client_tokens, :selected_account_public_id, algorithm: :concurrently
    add_index :client_tokens, :selected_collective_public_id, algorithm: :concurrently
    add_index :client_tokens, :selected_avatar_public_id, algorithm: :concurrently
  end
end
