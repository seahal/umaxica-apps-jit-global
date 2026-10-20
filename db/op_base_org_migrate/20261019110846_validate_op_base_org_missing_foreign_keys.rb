# frozen_string_literal: true

class ValidateOpBaseOrgMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:operator_tokens, name: "fk_operator_tokens_on_oidc_connection_id")
  end
end
