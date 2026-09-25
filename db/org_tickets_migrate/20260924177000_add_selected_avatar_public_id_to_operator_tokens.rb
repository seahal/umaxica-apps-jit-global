# typed: false
# frozen_string_literal: true

class AddSelectedAvatarPublicIdToOperatorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :operator_tokens, :selected_avatar_public_id, :string
    add_index :operator_tokens, :selected_avatar_public_id, algorithm: :concurrently
  end
end
