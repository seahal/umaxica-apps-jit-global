# frozen_string_literal: true

class ValidateOperatorPreferencePublicIdNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :operator_preferences
  NOT_NULL_CONSTRAINT = "#{TABLE}_public_id_not_null"
  NONBLANK_CONSTRAINT = "#{TABLE}_public_id_nonblank"

  def up
    validate_check_constraint(TABLE, name: NOT_NULL_CONSTRAINT)
    validate_check_constraint(TABLE, name: NONBLANK_CONSTRAINT)
    change_column_null(TABLE, :public_id, false)
    remove_check_constraint(TABLE, name: NOT_NULL_CONSTRAINT)
    remove_check_constraint(TABLE, name: NONBLANK_CONSTRAINT)
  end

  def down
    add_check_constraint(
      TABLE,
      "public_id IS NOT NULL",
      name: NOT_NULL_CONSTRAINT,
      validate: false,
    )
    add_check_constraint(
      TABLE,
      "public_id IS NULL OR public_id !~ '^[[:space:]]*$'",
      name: NONBLANK_CONSTRAINT,
      validate: false,
    )
    change_column_null(TABLE, :public_id, true)
  end
end
