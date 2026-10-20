# frozen_string_literal: true

class AddOpBaseComMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :visitor_tokens, :visitor_oidc_connections, column: :oidc_connection_id, name: "fk_visitor_tokens_on_oidc_connection_id",
                                                  on_delete: :nullify, validate: false,
    )
  end
end
