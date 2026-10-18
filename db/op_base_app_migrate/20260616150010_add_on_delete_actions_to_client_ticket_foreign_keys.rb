# frozen_string_literal: true

class AddOnDeleteActionsToClientTicketForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:client_sign_up_flows, column: :token_id) if foreign_key_exists?(:client_sign_up_flows, column: :token_id)
    remove_foreign_key(:client_sign_up_flows, column: :status_id) if foreign_key_exists?(:client_sign_up_flows, column: :status_id)
    remove_foreign_key(:client_tokens, column: :user_token_kind_id) if foreign_key_exists?(:client_tokens, column: :user_token_kind_id)
    remove_foreign_key(:client_tokens, column: :user_token_status_id) if foreign_key_exists?(:client_tokens, column: :user_token_status_id)

    add_foreign_key :client_sign_up_flows, :client_tokens, column: :token_id, on_delete: :cascade, validate: false
    add_foreign_key :client_sign_up_flows, :client_sign_up_flow_statuses, column: :status_id, on_delete: :restrict, validate: false
    add_foreign_key :client_tokens, :client_token_kinds, column: :user_token_kind_id, on_delete: :restrict, validate: false
    add_foreign_key :client_tokens, :client_token_statuses, column: :user_token_status_id, on_delete: :restrict, validate: false
  end

  def down
    remove_foreign_key(:client_sign_up_flows, column: :token_id) if foreign_key_exists?(:client_sign_up_flows, column: :token_id)
    remove_foreign_key(:client_sign_up_flows, column: :status_id) if foreign_key_exists?(:client_sign_up_flows, column: :status_id)
    remove_foreign_key(:client_tokens, column: :user_token_kind_id) if foreign_key_exists?(:client_tokens, column: :user_token_kind_id)
    remove_foreign_key(:client_tokens, column: :user_token_status_id) if foreign_key_exists?(:client_tokens, column: :user_token_status_id)

    add_foreign_key :client_sign_up_flows, :client_tokens, column: :token_id, validate: false
    add_foreign_key :client_sign_up_flows, :client_sign_up_flow_statuses, column: :status_id, validate: false
    add_foreign_key :client_tokens, :client_token_kinds, column: :user_token_kind_id, validate: false
    add_foreign_key :client_tokens, :client_token_statuses, column: :user_token_status_id, validate: false
  end
end
