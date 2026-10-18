# frozen_string_literal: true

class AddNotNullChecksToClientPublicIds < ActiveRecord::Migration[8.2]
  TABLES = %i(client_preferences client_passkeys).freeze

  def change
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
    end
  end
end
