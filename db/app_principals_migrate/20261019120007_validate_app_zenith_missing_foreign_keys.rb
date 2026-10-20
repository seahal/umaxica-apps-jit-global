# frozen_string_literal: true

class ValidateAppZenithMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:client_profiles, name: "fk_client_profiles_on_user_id")
    validate_foreign_key(:client_accounts, name: "fk_client_accounts_on_user_id")
    validate_foreign_key(:core_app_client_bridges, name: "fk_core_app_client_bridges_on_client_id")
  end
end
