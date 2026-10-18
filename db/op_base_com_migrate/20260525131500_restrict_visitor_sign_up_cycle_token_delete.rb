# frozen_string_literal: true
class RestrictVisitorSignUpCycleTokenDelete < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key :visitor_sign_up_cycles, column: :token_id, if_exists: true
    add_foreign_key :visitor_sign_up_cycles, :visitor_tokens, column: :token_id, validate: false
  end

  def down
    remove_foreign_key :visitor_sign_up_cycles, column: :token_id, if_exists: true
    add_foreign_key :visitor_sign_up_cycles, :visitor_tokens, column: :token_id, on_delete: :cascade, validate: false
  end
end
