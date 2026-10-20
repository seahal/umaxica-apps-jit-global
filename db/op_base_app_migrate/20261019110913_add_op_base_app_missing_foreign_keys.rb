# frozen_string_literal: true

class AddOpBaseAppMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :client_tokens, :client_oidc_connections, column: :oidc_connection_id, name: "fk_client_tokens_on_oidc_connection_id",
                                                on_delete: :nullify, validate: false,
    )
  end
end
