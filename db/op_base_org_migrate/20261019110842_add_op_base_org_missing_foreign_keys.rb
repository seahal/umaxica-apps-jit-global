# frozen_string_literal: true

class AddOpBaseOrgMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :operator_tokens, :operator_oidc_connections, column: :oidc_connection_id, name: "fk_operator_tokens_on_oidc_connection_id",
                                                    on_delete: :nullify, validate: false,
    )
  end
end
