# frozen_string_literal: true

class ValidateComZenithMissingForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:visitor_accounts, name: "fk_visitor_accounts_on_visitor_id")
    validate_foreign_key(:core_com_visitor_bridges, name: "fk_core_com_visitor_bridges_on_visitor_id")
  end
end
