# frozen_string_literal: true

class AddOnDeleteActionsToVisitorTicketForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:visitor_sign_up_flows, column: :token_id) if foreign_key_exists?(:visitor_sign_up_flows, column: :token_id)
    remove_foreign_key(:visitor_sign_up_flows, column: :status_id) if foreign_key_exists?(:visitor_sign_up_flows, column: :status_id)

    add_foreign_key :visitor_sign_up_flows, :visitor_tokens, column: :token_id, on_delete: :cascade, validate: false
    add_foreign_key :visitor_sign_up_flows, :visitor_sign_up_flow_statuses, column: :status_id, on_delete: :restrict, validate: false
  end

  def down
    remove_foreign_key(:visitor_sign_up_flows, column: :token_id) if foreign_key_exists?(:visitor_sign_up_flows, column: :token_id)
    remove_foreign_key(:visitor_sign_up_flows, column: :status_id) if foreign_key_exists?(:visitor_sign_up_flows, column: :status_id)

    add_foreign_key :visitor_sign_up_flows, :visitor_tokens, column: :token_id, validate: false
    add_foreign_key :visitor_sign_up_flows, :visitor_sign_up_flow_statuses, column: :status_id, validate: false
  end
end
