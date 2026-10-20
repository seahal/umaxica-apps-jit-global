# frozen_string_literal: true

class ValidateOpBaseAppMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:client_tokens, name: "fk_client_tokens_on_oidc_connection_id")
  end
end
