# frozen_string_literal: true

class ValidateComPreferencePublicIdCapacityCheck < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :com_preferences
  CONSTRAINT = "com_preferences_public_id_max_length"
  EXPRESSION = "char_length(public_id) <= 25"

  def up
    validate_check_constraint(TABLE, name: CONSTRAINT)
  end

  def down
    remove_check_constraint(TABLE, name: CONSTRAINT)
    add_check_constraint(TABLE, EXPRESSION, name: CONSTRAINT, validate: false)
  end
end
