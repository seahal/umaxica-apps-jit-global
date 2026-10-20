# frozen_string_literal: true

class ValidateCascadeOpBaseComDependentDeletes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:visitor_verifications, name: "fk_visitor_verifications_on_visitor_token_id")
  end
end
