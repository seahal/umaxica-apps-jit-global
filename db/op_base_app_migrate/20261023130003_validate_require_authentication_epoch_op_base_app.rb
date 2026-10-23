# frozen_string_literal: true

# Validates the WU-17 checks, then replaces the validated NOT NULL check with the column constraint.
class ValidateRequireAuthenticationEpochOpBaseApp < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i(client_tokens op_app_grants).freeze

  def up
    TABLES.each do |table|
      validate_check_constraint(table, name: "chk_#{table}_authentication_epoch")
      validate_check_constraint(table, name: "chk_#{table}_authentication_epoch_nn")
      change_column_null(table, :authentication_epoch, false)
      remove_check_constraint(table, name: "chk_#{table}_authentication_epoch_nn")
    end
  end

  def down
    TABLES.each do |table|
      add_check_constraint(
        table, "authentication_epoch IS NOT NULL", name: "chk_#{table}_authentication_epoch_nn", validate: false,
      )
      change_column_null(table, :authentication_epoch, true)
    end
  end
end
