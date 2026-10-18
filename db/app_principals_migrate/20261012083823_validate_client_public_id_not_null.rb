# frozen_string_literal: true

class ValidateClientPublicIdNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i(client_preferences client_passkeys).freeze

  def up
    TABLES.each do |table|
      not_null = "#{table}_public_id_not_null"
      nonblank = "#{table}_public_id_nonblank"
      validate_check_constraint(table, name: not_null)
      validate_check_constraint(table, name: nonblank)
      change_column_null(table, :public_id, false)
      remove_check_constraint(table, name: not_null)
      remove_check_constraint(table, name: nonblank)
    end
  end

  def down
    TABLES.each do |table|
      add_check_constraint(
        table,
        "public_id IS NOT NULL",
        name: "#{table}_public_id_not_null",
        validate: false,
      )
      add_check_constraint(
        table,
        "public_id IS NULL OR public_id !~ '^[[:space:]]*$'",
        name: "#{table}_public_id_nonblank",
        validate: false,
      )
      change_column_null(table, :public_id, true)
    end
  end
end
