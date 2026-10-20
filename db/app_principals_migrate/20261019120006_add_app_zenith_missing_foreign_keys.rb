# frozen_string_literal: true

class AddAppZenithMissingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :client_profiles, :clients, column: :user_id, name: "fk_client_profiles_on_user_id",
                                  on_delete: :nullify, validate: false,
    )
    add_foreign_key(
      :client_accounts, :clients, column: :user_id, name: "fk_client_accounts_on_user_id",
                                  on_delete: :restrict, validate: false,
    )
    add_foreign_key(
      :core_app_client_bridges, :clients, column: :client_id, name: "fk_core_app_client_bridges_on_client_id",
                                          on_delete: :restrict, validate: false,
    )
  end
end
