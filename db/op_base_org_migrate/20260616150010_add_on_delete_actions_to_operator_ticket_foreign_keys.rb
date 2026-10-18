# frozen_string_literal: true

class AddOnDeleteActionsToOperatorTicketForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:operator_tokens, column: :staff_token_kind_id) if foreign_key_exists?(:operator_tokens, column: :staff_token_kind_id)
    remove_foreign_key(:operator_tokens, column: :staff_token_status_id) if foreign_key_exists?(:operator_tokens, column: :staff_token_status_id)

    add_foreign_key :operator_tokens, :operator_token_kinds, column: :staff_token_kind_id, on_delete: :restrict, validate: false
    add_foreign_key :operator_tokens, :operator_token_statuses, column: :staff_token_status_id, on_delete: :restrict, validate: false
  end

  def down
    remove_foreign_key(:operator_tokens, column: :staff_token_kind_id) if foreign_key_exists?(:operator_tokens, column: :staff_token_kind_id)
    remove_foreign_key(:operator_tokens, column: :staff_token_status_id) if foreign_key_exists?(:operator_tokens, column: :staff_token_status_id)

    add_foreign_key :operator_tokens, :operator_token_kinds, column: :staff_token_kind_id, validate: false
    add_foreign_key :operator_tokens, :operator_token_statuses, column: :staff_token_status_id, validate: false
  end
end
