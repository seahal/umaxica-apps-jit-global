# frozen_string_literal: true

class AddOwnedPublicIdCapacityChecksToAppPrincipals < ActiveRecord::Migration[8.2]
  TABLES = [:members].freeze
  EXPRESSION = "char_length(public_id) <= 25"

  def up
    TABLES.each do |table|
      add_check_constraint(
        table,
        EXPRESSION,
        name: "#{table}_public_id_max_length",
        validate: false,
      )
    end
  end

  def down
    TABLES.each do |table|
      remove_check_constraint(table, name: "#{table}_public_id_max_length")
    end
  end
end
