# frozen_string_literal: true

class RestrictVisitorSignUpFlowTokenDelete < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:visitor_sign_up_flows, column: :token_id, if_exists: true)
    add_foreign_key(
      :visitor_sign_up_flows,
      :visitor_tokens,
      column: :token_id,
      on_delete: :restrict,
      validate: false,
    )
  end

  def down
    remove_foreign_key(:visitor_sign_up_flows, column: :token_id, if_exists: true)
    add_foreign_key(:visitor_sign_up_flows, :visitor_tokens, column: :token_id, on_delete: :cascade)
  end
end
