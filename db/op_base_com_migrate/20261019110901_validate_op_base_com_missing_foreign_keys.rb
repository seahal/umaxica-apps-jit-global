# frozen_string_literal: true

class ValidateOpBaseComMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:visitor_tokens, name: "fk_visitor_tokens_on_oidc_connection_id")
  end
end
